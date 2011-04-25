require 'rubygems'
require 'bundler'
Bundler.setup

require 'logger'
require 'sinatra/base'

require 'sinatra'
require 'sinatra/sequel'

require 'rack-flash'

Sequel::Model.raise_on_save_failure = true
require 'erb'

require_relative 'lib/tumblr_api'

ENV['DATABASE_URL'] ||= "sqlite://#{Dir.pwd}/tumblr_machine.sqlite3"

['email', 'password', 'tumblr_name'].each do |p|
  unless ENV.include? p
    raise "Missing #{p} environment variable"
  end
end

class TumblrMachine< Sinatra::Base

  set :app_file, __FILE__
  set :root, File.dirname(__FILE__)
  set :static, true
  set :public, Proc.new { File.join(root, "public") }
  set :views, Proc.new { File.join(root, "views") }

  set :raise_errors, true
  set :show_exceptions, true

  configure :development do
    set :logging, true
    database.loggers << Logger.new(STDOUT)
  end

  use Rack::Session::Pool
  use Rack::Flash

  Sequel.extension :blank

  require_relative 'lib/models'
  require_relative 'lib/helpers'

  helpers Sinatra::TumblrMachineHelper

  # admin
  get '/' do
    @tags = database['select tags.name n, tags.fetch f, tags.last_fetch l, tags.value v, count(posts_tags.post_id) c ' +
                         'from tags left join posts_tags on tags.id = posts_tags.tag_id ' +
                         'group by tags.name ' +
                         'order by tags.fetch desc, tags.value desc, c desc,  tags.name asc']
    @posts = Post.eager(:tumblr).eager(:tags).filter(:posted => false).filter(:tumblr_id => Tumblr.select(:id).filter('tumblrs.last_reblogged_post is null or tumblrs.last_reblogged_post > ?', (DateTime.now << 1))).order(:score.desc).limit(10)
    erb :'admin.html'
  end

  post '/edit_tag' do
    name = params[:tagName]
    value = params[:tagValue]
    if name.blank?
      flash[:error] = 'Tag name is empty'
      redirect '/'
    elsif value.blank?
      flash[:error] = 'Tag value is empty'
      redirect '/'
    else
      begin
        value = Integer(value)
      rescue ArgumentError
        flash[:error] = "#{value} is not a valid value"
        redirect '/'
      end
      if value == 0
        value = nil
      end

      if tag = Tag.first(:name => name)
        delta = (value || 0) - (tag.value || 0)
        updates = {:value => value, :fetch => (params[:tagFetch] || false)}
        unless tag.fetch
          updates[:last_fetch] = nil
        end
        tag.update(updates)

        if tag.fetch
          fetch_tag(tag)
        end

        if delta != 0
          Post.filter('posts.id in (select posts_tags.post_id from posts_tags where posts_tags.tag_id = ?)', tag.id).update(:score => :score + delta)
        end
        flash[:notice] = 'Tag updated'
      else
        tag = Tag.create(:name => name, :value => value, :fetch => (params[:tagFetch] || false))
        if tag.fetch
          fetch_tag(tag)
        end
        flash[:notice] = 'Tag added'
      end

      redirect '/'
    end
  end

  # Fetch this tag
  get '/fetch/:tag' do
    tag = Tag.filter(:name => params[:tag]).first
    posts_count = fetch_tag(tag.name, tag)
    "Fetched [#{params[:tag]}], #{posts_count} posts added\n"
  end

  # fetch content of next tag
  get '/fetch_next_tag' do
    tag = Tag.filter(:fetch => true).order(:last_fetch.asc).first
    if tag
      posts_count = fetch_tag(tag.name, tag)
      "Fetched [#{tag.name}], #{posts_count} posts added\n"
    else
      "Nothing to fetch\n"
    end
  end

  # reblog
  get '/reblog_next' do
    post = Post.eager(:tumblr).eager(:tags).filter(:posted => false).filter(:tumblr_id => Tumblr.select(:id).filter('tumblrs.last_reblogged_post is null or tumblrs.last_reblogged_post > ?', (DateTime.now << 1))).order(:score.desc).first
    if post
      reblog_key = TumblrApi.reblog_key(post.tumblr.url, post.id)
      TumblrApi.reblog(ENV['email'], ENV['password'], ENV['tumblr_name'], post.id, reblog_key, post.tags.collect { |t| t.name })
      post.update(:posted => true)
      Tumblr.filter(:id => post.tumblr_id).update(:last_reblogged_post => DateTime.now)
      "Posted #{post.tumblr.url}/post/#{post.id}\n"
    else
      "Nothing to post\n"
    end
  end

  # clean old posts
  get '/clean' do
    Post.filter('fetched < ?', (DateTime.now - 15)).destroy
    Tumblr.filter('id not in (select distinct(tumblr_id) from posts)').filter('last_reblogged_post < ?', (DateTime.now << 1)).delete
    Tag.filter(:fetch => false, :value => nil).filter('id not in (select distinct(tag_id) from posts_tags)').delete
  end

  private

  # Fetch a tag.
  # Parameters:
  # - tag_name the tag name
  # - tag the tag, may be null
  def fetch_tag tag_name, tag = nil
    posts_count = 0

    # Small cache to avoid fetching same tags for each post
    fetched_tags = {}
    TumblrApi.fetch_tag(tag_name).each do |post|
      unless (Post.first(:id => post[:id])) || (post[:tumblr_name] == ENV['tumblr_name'])
        posts_count += 1
        post_db = Post.new
        post_db.id = post[:id]
        unless tumblr = Tumblr.first(:name => post[:tumblr_name])
          tumblr = Tumblr.create(:name => post[:tumblr_name], :url => post[:tumblr_url])
        end
        post_db.tumblr = tumblr
        post_db.fetched = DateTime.now
        post_db.save

        score = 0
        if tag
          score += tag.value || 0
          post_db.add_tag tag
        end

        post[:tags].each do |t|
          if ta = fetched_tags[t] || Tag.first(:name => t)
            if ta.value
              score += ta.value
            end
          else
            ta = Tag.create(:name => t, :value => nil, :fetch => false)
            fetched_tags[t] = ta
          end
          post_db.add_tag ta
        end
        post_db.update({:score => score})
      end
    end
    if tag
      tag.update(:last_fetch => DateTime.now)
    end
    posts_count
  end

end
