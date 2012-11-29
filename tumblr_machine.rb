['consumer_key', 'secret_key', 'tumblr_name', 'openid_uri'].each do |p|
  unless ENV.include? p
    raise "Missing #{p} environment variable"
  end
end

# if we enable deduplication
DEDUPLICATION = ENV['deduplication']

# the level above we consider an image is a duplicate of another
DUPLICATE_LEVEL = 0.8125

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

ENV['DATABASE_URL'] ||= "sqlite://#{Dir.pwd}/tumblr-machine.sqlite3"

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

  require 'rack/openid'
  use Rack::OpenID

  helpers Sinatra::TumblrMachineHelper

  before do
    @user_logged = session[:user]

    @consumer = OAuth::Consumer.new(
        ENV['consumer_key'],
        ENV['secret_key'],
        {
            :site => "http://www.tumblr.com",
            :scheme => :header,
            :http_method => :post,
            :request_token_path => "/oauth/request_token",
            :authorize_path => "/oauth/authorize"
        })

    if session[:access_token]
      @access_token = session[:access_token]
    elsif ((meta_access_token_token = Meta.first(:key => 'access_token_token')) &&
        (meta_access_token_secret = Meta.first(:key => 'access_token_secret')))
      @access_token = OAuth::AccessToken.new(@consumer, meta_access_token_token.value, meta_access_token_secret.value)
    end
  end

  # admin
  get '/' do
    check_logged
    @total_posts = Post.count
    @waiting_posts = Post.
        where('skip != ?', true).
        where('posted = ?', false).
        where('tumblr_id not in (?)', skippable_tumblr_ids).
        where('score >= 2').
        count
    @posts = next_posts().limit(40)
    headers "Cache-Control" => "no-cache, must-revalidate"
    erb :'index.html'
  end

  get '/tags' do
    check_logged
    @tags = database['select tags.name as n, tags.fetch as f, tags.last_fetch as l, tags.value as v, count(posts_tags.post_id) as c ' +
                         'from tags left join posts_tags on tags.id = posts_tags.tag_id ' +
                         'where tags.value != 0 or tags.fetch = ? ' +
                         'group by tags.name, tags.fetch, tags.last_fetch, tags.value ' +
                         'order by tags.fetch desc, tags.value desc, c desc, tags.name asc', true]
    headers "Cache-Control" => "no-cache, must-revalidate"
    erb :'tags.html'
  end

  # reblog the next post
  get '/other_tags' do
    check_logged_ajax

    @tags = database['select tags.name as n, count(posts_tags.post_id) as c ' +
                         'from tags left join posts_tags on tags.id = posts_tags.tag_id ' +
                         'where tags.value = 0 and tags.fetch = ? ' +
                         'group by tags.name ' +
                         'order by c desc, tags.name asc', false]
    erb :'other_tags.html'
  end

  post '/edit_tag' do
    check_logged

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

      if tag = Tag.first(:name => name)
        delta = value - tag.value
        updates = {:value => value, :fetch => (params[:tagFetch] || false)}
        unless tag.fetch
          updates[:last_fetch] = nil
        end
        tag.update(updates)

        if tag.fetch
          fetch_tags [tag.name], {name => tag}
        end

        if delta != 0
          Post.where('posts.id in (select posts_tags.post_id from posts_tags where posts_tags.tag_id = ?)', tag.id).
              update(:score => :score + delta)
        end
        flash[:notice] = 'Tag updated'
      else
        tag = Tag.create(:name => name, :value => value, :fetch => (params[:tagFetch] || false))
        if tag.fetch
          fetch_tags [tag.name], {name => tag}
        end
        flash[:notice] = 'Tag added'
      end

      redirect '/'
    end
  end

  # Fetch a tag
  get '/fetch/:tag_name' do
    check_logged

    tag = Tag.filter(:name => params[:tag_name]).first
    posts_count = fetch_tags([tag.name], {tag.name => tag})
    flash[:notice] = "Fetched [#{params[:tag_name]}], #{posts_count} posts added"
    redirect '/'
  end

  # fetch next tag from external source
  get '/fetch_next_tags_external' do
    tags = Tag.filter(:fetch => true).order(:last_fetch.asc)
    cache = {}
    tags_names = []
    tags.each do |t|
      cache[t.name] = t
      tags_names << t.name
    end
    fetch_tags tags_names, cache

    headers "Cache-Control" => "no-cache, must-revalidate"
    "OK"
  end


  # fetch content of next tags
  post '/fetch_next_tags' do
    check_logged

    tags = Tag.filter(:fetch => true).order(:last_fetch.asc)
    cache = {}
    tags_names = []
    tags.each do |t|
      cache[t.name] = t
      tags_names << t.name
    end
    posts_count = fetch_tags tags_names, cache

    flash[:notice] = "Fetched #{tags_names.join(', ')}: #{posts_count} posts added"
    redirect '/'
  end

  get '/fetch_next_tags' do
    redirect '/'
  end


  post '/skip_unposted' do
    check_logged
    Post.filter(:id => params[:posts].split(',').collect { |i| i.to_i }).filter(:skip => nil).filter(:posted => false).update({:skip => true})
    redirect '/'
  end

  # Reblog a post
  get '/reblog/:id' do
    check_logged_ajax

    post = Post.eager(:tumblr).eager(:tags).filter(:id => params[:id]).first
    if post
      reblog post
      "Posted #{post.tumblr.url}/post/#{post.id}"
    else
      "Post not found"
    end
  end

  # clean old posts
  post '/clean' do
    check_logged

    Post.filter('fetched < ?', (DateTime.now - 15)).destroy
    Tumblr.filter('id not in (select distinct(tumblr_id) from posts)').filter('last_reblogged_post < ?', (DateTime.now << 1)).delete
    Tag.filter(:fetch => false, :value => 0).filter('id not in (select distinct(tag_id) from posts_tags)').delete
    flash[:notice] = "Cleaning done"
    redirect '/'
  end

  # in case we do a refresh
  get '/clean' do
    redirect '/'
  end

  # recalculate score of existing posts
  get '/recalculate_scores' do
    check_logged_ajax

    database.run "update posts set score = (select sum(tags.value) from tags where tags.id in (select posts_tags.tag_id from posts_tags where posts_tags.post_id = posts.id))"
    "OK"
  end

  private

  # Fetch a tag.
  # Parameters:
  # - tags_names the tags names
  # - hash of fetched_tags tags already fetched indexed by their names
  def fetch_tags tags_names, fetched_tags = {}
    posts_count = 0

    if DEDUPLICATION
      hydra = Typhoeus::Hydra.new({:max_concurrency => 4})
      hydra.disable_memoization
      TumblrApi.fetch_tags(tags_names) do |values|
        if post = create_post(values, fetched_tags)
          posts_count += 1
          if post.img_url
            hydra.queue create_deduplication_request(post)
          end
        end
      end
      hydra.run
    else
      TumblrApi.fetch_tags(tags_names) do |values|
        if create_post(values, fetched_tags)
          posts_count += 1
        end
      end
    end

    Tag.filter(:name => tags_names).update(:last_fetch => DateTime.now)
    posts_count
  end


  # Create the request to manage deduplication
  # post:: the post we do the stuff for
  # return the Request
  def create_deduplication_request post
    request = Typhoeus::Request.new post.img_url
    request.on_complete do |response|
      if response.code == 200
        file = Tempfile.new('tumblr-machine')
        begin
          file.write response.body
          file.close
          fingerprint = Phashion::Image.new(file.path).fingerprint
          post.update({:fingerprint => Sequel::LiteralString.new("B'#{fingerprint.to_s(2).rjust(64, '0')}'")})

          if database[:posts].
              where('fingerprint is not null').
              where('id != ?', post.id).
              where('hamming(fingerprint, (select fingerprint from posts where id = ?)) >= ?', post.id, DUPLICATE_LEVEL).
              count > 0
            post.update({:skip => true})
          end

        ensure
          file.close
          file.unlink
        end
      end
    end
    request
  end

  # Create a post if it does not exist
  # values:: the values used to create the post
  # fetched_tags:: tags already fetched to be used as a cache
  # return the Post object
  def create_post values, fetched_tags
    unless (Post.first(:id => values[:id])) || (values[:tumblr_name] == ENV['tumblr_name'])
      post_db = Post.new
      post_db.id = values[:id]
      if tumblr = Tumblr.first(:url => values[:tumblr_url])
        if tumblr.name != values[:tumblr_name]
          tumblr.update(:name => values[:tumblr_name])
        end
      else
        tumblr = Tumblr.create(:name => values[:tumblr_name], :url => values[:tumblr_url])
      end
      post_db.tumblr = tumblr
      post_db.score = 0
      post_db.fetched = DateTime.now
      post_db.img_url = values[:img_url]
      post_db.height = values[:height]
      post_db.width = values[:width]
      unless values[:img_url]
        post_db.skip = true
      end
      post_db.save
      score = 0

      values[:tags].each do |t|
        if ta = fetched_tags[t] || Tag.first(:name => t)
          score += ta.value
        else
          ta = Tag.create(:name => t, :value => 0, :fetch => false, :value => 0)
          fetched_tags[t] = ta
        end
        post_db.add_tag ta
      end
      post_db.update({:score => score})
      post_db
    end
  end

  # Reblog a post
  def reblog post
    reblog_key = TumblrApi.reblog_key(ENV['consumer_key'], post.tumblr.name, post.id)
    TumblrApi.reblog(@access_token, ENV['tumblr_name'], post.id, reblog_key)
    post.update(:posted => true)
    Tumblr.filter(:id => post.tumblr_id).update(:last_reblogged_post => DateTime.now)
  end

  # Finder for the next posts
  def next_posts
    Post.
        eager(:tumblr).
        eager(:tags).
        where('skip != ?', true).
        where(:posted => false).
        where('tumblr_id not in (?)', skippable_tumblr_ids).
        order(:score.desc, :fetched.desc)
  end

  def skippable_tumblr_ids
    Tumblr.
        select(:id).
        where('tumblrs.last_reblogged_post is not null and tumblrs.last_reblogged_post > ?', (DateTime.now << 1))
  end

end

require_relative 'lib/login'
