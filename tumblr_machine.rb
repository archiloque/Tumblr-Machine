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
    erb :'admin.html'
  end

  post '/add_tag' do
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
        if delta != 0
          Post.filter('posts.id in (select posts_tags.post_id from posts_tags where posts_tags.tag_id = ?)', tag.id).update(:score => :score + delta)
        end
        flash[:notice] = 'Tag updated'
      else
        Tag.create(:name => name, :value => value, :fetch => (params[:tagFetch] || false))
        flash[:notice] = 'Tag added'
      end

      redirect '/'
    end
  end

  get '/fetch' do
    tag = Tag.filter(:fetch => true).order(:last_fetch.asc).first
    if tag
      TumblrApi.fetch_tag(tag.name).each do |post|
        unless (Post.first(:id => post[:id])) || (post[:tumblr_name] == ENV['tumblr_name'])
          post_db = Post.new
          post_db.id = post[:id]
          unless tumblr = Tumblr.first(:name => post[:tumblr_name])
            tumblr = Tumblr.create(:name => post[:tumblr_name], :url => post[:tumblr_url])
          end
          post_db.tumblr = tumblr
          post_db.fetched = DateTime.now
          post_db.save

          score = tag.value || 0

          post_db.add_tag tag
          post[:tags].each do |t|
            if ta = Tag.first(:name => t)
              if tag.value
                score += tag.value
              end
            else
              ta = Tag.create(:name => t, :value => 0, :fetch => false)
            end
            post_db.add_tag ta
          end

          post_db.update({:score => score})
        end
      end
      tag.update(:last_fetch => DateTime.now)
      "Fetched #{tag.name}\n"
    else
      "Nothing to fetch\n"
    end
  end

  get '/post' do
    post = Post.eager(:tumblr).filter(:posted => false).filter(:tumblr_id => Tumblr.select(:id).filter('tumblrs.last_reblogged_post is null or tumblrs.last_reblogged_post > ?', (DateTime.now << 1))).order(:score.desc).first
    if post
      reblog_key = TumblrApi.reblog_key(post.tumblr.url, post.id)
      TumblrApi.reblog(ENV['email'], ENV['password'], ENV['tumblr_name'], post.id, reblog_key)
      post.update(:posted => true)
      Tumblr.filter(:id => post.tumblr_id).update(:last_reblogged_post => DateTime.now)
      "Posted #{post.tumblr.url}/post/#{post.id}\n"
    else
      "Nothing to post\n"
    end

  end

end
