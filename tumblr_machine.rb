['consumer_key', 'secret_key', 'tumblr_name'].each do |p|
  unless ENV.include? p
    raise "Missing #{p} environment variable"
  end
end

unless ENV.include? 'http_x_ssl_issuer'
  p 'No http_x_ssl_issuer env variable, app will be run without authentication'
end

MIN_SCORE = 2

# the level above we consider an image is a duplicate of another
DUPLICATE_LEVEL = 0.8125

require 'yajl'
require 'logger'
require 'sinatra/base'
require 'typhoeus'
require 'phashion'
require 'rack-flash'
require 'sequel'
require 'thread'

Sequel::Model.raise_on_save_failure = true
require 'erb'

require_relative 'lib/tumblr_api'

ENV['DATABASE_URL'] ||= "sqlite://#{Dir.pwd}/tumblr-machine.sqlite3"

class TumblrMachine < Sinatra::Base

  set :app_file, __FILE__
  set :root, File.dirname(__FILE__)
  set :static, true
  set :public_dir, Proc.new { File.join(root, 'public') }
  set :views, Proc.new { File.join(root, 'views') }

  STORED_IMAGES_DIR = File.join(root, 'public/stored_images')
  DATABASE = Sequel.connect(ENV['DATABASE_URL'])

  unless Dir.exists? STORED_IMAGES_DIR
    Dir.mkdir STORED_IMAGES_DIR
  end

  set :raise_errors, true
  set :show_exceptions, true

  configure :development do
    set :logging, true
    DATABASE.loggers << Logger.new(STDOUT)
  end

  use Rack::Session::Pool
  use Rack::Flash

  Sequel.extension :blank

  require_relative 'lib/models'
  require_relative 'lib/helpers'

  Typhoeus::Config.memoize = false

  # Return a result as a json message
  # @param code [Integer] the result code
  # @param message [String] the content message
  def json(code, message)
    content_type :json
    halt code, Yajl::Encoder.encode(message)
  end

  helpers Sinatra::TumblrMachineHelper

  before do
    @user_logged = session[:user]

    @consumer = OAuth::Consumer.new(
        ENV['consumer_key'],
        ENV['secret_key'],
        {
            :site => 'http://www.tumblr.com',
            :scheme => :header,
            :http_method => :post,
            :request_token_path => '/oauth/request_token',
            :authorize_path => '/oauth/authorize'
        })

    if session[:access_token]
      @access_token = session[:access_token]
    elsif (meta_access_token_token = Meta.first(:key => 'access_token_token')) &&
        (meta_access_token_secret = Meta.first(:key => 'access_token_secret'))
      @access_token = OAuth::AccessToken.new(@consumer, meta_access_token_token.value, meta_access_token_secret.value)
    end
  end

  get '/' do
    check_logged
    @total_posts = Post.count
    @number_waiting_posts = Post.
        where('skip is not ?', true).
        where('posted = ?', false).
        where('tumblr_id not in (?)', skippable_tumblr_ids).
        where('score >= ?', MIN_SCORE).
        count
    @posts = next_posts().limit(500).to_a

    tags_with_score = tags_with_score_in_hash

    tumblrs_by_id = {}
    Tumblr.where(:id => @posts.collect { |post| post.tumblr_id }.uniq).each do |tumblr|
      tumblrs_by_id[tumblr.id] = tumblr
    end

    @posts.each do |post|
      post.loaded_tumblr = tumblrs_by_id[post.tumblr_id]
      if post.tags
        post.loaded_tags = post.tags.
            sort.
            collect { |tag| {:name => tag, :value => (tags_with_score[tag] || 0)} }
      else
        post.loaded_tags = []
      end
    end

    headers 'Cache-Control' => 'no-cache, must-revalidate'
    @stored_images_dir = STORED_IMAGES_DIR
    erb :'index.html'
  end

  get '/tags' do
    check_logged
    @tags = DATABASE['select
	tags.name as n,
	tags.fetch as f,
	tags.last_fetch as l,
	tags.value as v,
	(select count (*) from posts where tags.name=ANY(posts.tags)) as c
from tags
where tags.value != 0 or tags.fetch = TRUE
order by tags.fetch desc, tags.value desc, c desc, tags.name asc']
    headers 'Cache-Control' => 'no-cache, must-revalidate'
    erb :'tags.html'
  end

  get '/all_tags' do
    check_logged_ajax

    @tags = DATABASE['select count(*) as c, unnest(posts.tags) as n from posts group by n order by c desc, n asc']
    erb :'all_tags.html'
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

      name.downcase!

      if (tag = Tag.first(:name => name))
        delta = value - tag.value
        updates = {:value => value, :fetch => (params[:tagFetch] || false)}
        unless tag.fetch
          updates[:last_fetch] = nil
        end
        tag.update(updates)

        if tag.fetch
          fetch_tags([tag.name])
        end

        if delta != 0
          recalculate
        end
        flash[:notice] = 'Tag updated'
      else
        tag = Tag.create(:name => name, :value => value, :fetch => (params[:tagFetch] || false))
        if tag.fetch
          fetch_tags([tag.name])
        end
        flash[:notice] = 'Tag added'
      end

      redirect '/'
    end
  end

  # Fetch a tag
  get '/fetch/:tag_name' do
    check_logged

    tag = Tag.where(:name => params[:tag_name]).first
    posts_count = fetch_tags([tag.name])
    flash[:notice] = "Fetched [#{params[:tag_name]}], #{posts_count} posts added"
    redirect '/'
  end

  # fetch next tag from external source
  get '/fetch_next_tags_external' do
    tags = Tag.where(:fetch => true).order(Sequel.asc(:last_fetch))
    tags_names = []
    tags.each do |t|
      tags_names << t.name
    end
    fetch_tags(tags_names)
    headers 'Cache-Control' => 'no-cache, must-revalidate'
    'OK'
  end


  # fetch content of next tags
  post '/fetch_next_tags' do
    check_logged

    tags = Tag.where(:fetch => true).order(Sequel.asc(:last_fetch))
    tags_names = []
    tags.each do |t|
      tags_names << t.name
    end
    posts_count = fetch_tags(tags_names)

    flash[:notice] = "Fetched #{tags_names.join(', ')}: #{posts_count} posts added"
    redirect '/'
  end

  # in case we do a refresh
  get '/fetch_next_tags' do
    redirect '/'
  end

  post '/skip_unposted' do
    check_logged
    Post.where(:id => params[:posts].split(',').collect { |i| i.to_i }).
        where(:skip => nil).
        where(:posted => false).
        update({:skip => true})
    redirect '/'
  end

  # Reblog a post
  get '/reblog/:id' do
    check_logged_ajax

    post = Post.
        where(:id => params[:id]).
        first
    if post
      reblog(post)
      "Posted #{post.tumblr.url}/post/#{post.id}"
    else
      [404, 'Post not found']
    end
  end

  # clean old posts
  post '/clean' do
    check_logged

    Post.where('fetched < ?', (DateTime.now - 15)).delete

    DATABASE.transaction do
      Tumblr.
          where('id not in (select distinct(tumblr_id) from posts)').
          where('last_reblogged_post < ?', (DateTime.now << 1)).
          delete
    end

    DATABASE.transaction do
      # Garbage collect edited tag
      Tag.
          where(:fetch => false, :value => 0).
          delete
    end

    existing_files = {}
    Dir[File.join(STORED_IMAGES_DIR, '*.*')].each do |image_file|
      existing_files[File.basename(image_file, '.*')] = image_file
    end

    Post.where(:id => existing_files.keys).each do |existing_file|
      existing_files.delete(existing_file)
    end

    existing_files.values.each do |existing_file|
      File.unlink(existing_file)
    end

    flash[:notice] = 'Cleaning done'
    redirect '/'
  end

  # in case we do a refresh
  get '/clean' do
    redirect '/'
  end

  # recalculate score of existing posts
  get '/recalculate_scores' do
    check_logged_ajax
    recalculate
    'OK'
  end

  private

  # Fetch tags.
  # @param tags_names [Array<String>] the tags names
  # @return [Integer] the number of fetched posts
  def fetch_tags(tags_names)
    posts_count = 0

    hydra = Typhoeus::Hydra.new({:max_concurrency => 2})
    found_posts = TumblrApi.fetch_tags_from_tumblr(ENV['consumer_key'], tags_names)

    tags_with_score = tags_with_score_in_hash

    fingerprints = {}
    semaphore = Mutex.new
    found_posts.each do |found_post|
      begin
        if (post = create_post(found_post, tags_with_score))
          posts_count += 1
          if post.img_url && (post.score >= MIN_SCORE) && (!post.img_saved)
            hydra.queue(create_storage_request(post, fingerprints, semaphore))
          end
        end
      rescue Exception => e
        p e
      end
    end
    hydra.run

    fingerprints.each_pair do |post_id, fingerprint|
      post = Post.where(:id => post_id).first
      if fingerprint
        post.update({:img_saved => true, :fingerprint => fingerprint})
        unless Post.
            where('fingerprint is not null').
            where('id != ?', post_id).
            where('hamming(fingerprint, (select fingerprint from posts where id = ?)) >= ?', post_id, DUPLICATE_LEVEL).
            empty?
          post.update({:skip => true})
        end
      else
        post.update({:img_saved => true})
      end
    end

    Tag.where(:name => tags_names).update(:last_fetch => DateTime.now)
    posts_count
  end


  # Create the request to store an image
  # @params post [Post] the post we do the stuff for
  # @param fingerprints [Hash<Integer, String>] hash to add fingerprint
  # @param semaphore [Mutex] a mutex to synchronize
  # @return []Typhoeus::Request} the Request to add
  def create_storage_request(post, fingerprints, semaphore)
    request = Typhoeus::Request.new post.img_url
    request.on_complete do |response|
      if response.code == 200

        dest_file = File.join(STORED_IMAGES_DIR, "#{post.id}#{File.extname(post.img_url)}")
        File.open(dest_file, 'w') do |file|
          file.write response.body
        end

        semaphore.synchronize do
          if File.exist? dest_file
            post_fingerprint = Phashion::Image.new(dest_file).fingerprint
            fingerprints[post.id] = Sequel.lit("B'#{post_fingerprint.to_s(2).rjust(64, '0')}'")
          else
            fingerprints[post.id] = nil
          end
        end
      end
    end
    request
  end

  # Create a post if it does not exist
  # @param values [Hash] the values used to create the post
  # @fetched_tags [Hash<String, Integer>] fetched tags to be used
  # @return [Post] the Post object
  def create_post(values, tags_with_score)
    if values[:tumblr_name] == ENV['tumblr_name']
      return nil
    end

    tumblr_name = values[:tumblr_name]
    tumblr_url = values[:tumblr_url]
    DATABASE.transaction do
      DATABASE['INSERT INTO tumblrs (name, url) SELECT ?, ? WHERE NOT EXISTS (SELECT id FROM tumblrs WHERE url = ?)', tumblr_name, tumblr_url, tumblr_url].all
    end
    tumblr = Tumblr.first(:url => values[:tumblr_url])
    if tumblr.name != tumblr_name
      DATABASE.transaction do
        tumblr.update(:name => values[:tumblr_name])
      end
    end

    posts_insert_params = [
        [:tumblr_post_id, values[:id]],
        [:tumblr_id, tumblr.id],
        [:fetched, DateTime.now],
        [:reblog_key, values[:reblog_key]],
        [:tags, Sequel.pg_array(values[:tags], :text)],
        [:score, values[:tags].collect { |tag| tags_with_score[tag] || 0 }.inject(0, :+)]
    ]
    if values[:img_url]
      posts_insert_params << [:img_url, values[:img_url]]
      posts_insert_params << [:height, values[:height]]
      posts_insert_params << [:width, values[:width]]
    else
      posts_insert_params << [:skip, true]
    end

    post_insert_query = "INSERT INTO posts (#{posts_insert_params.collect { |param| param[0] }.join(', ')}) SELECT #{Array.new(posts_insert_params.length, '?').join(', ')} WHERE NOT EXISTS (SELECT id FROM posts WHERE tumblr_post_id = ?)"

    DATABASE.transaction do
      DATABASE[post_insert_query, *posts_insert_params.collect { |param| param[1] }, values[:id]].all
    end
    Post.first(:tumblr_post_id => values[:id])
  end

  # Reblog a post
  def reblog(post)
    unless (reblog_key = post.reblog_key)
      reblog_key = TumblrApi.get_reblog_key_from_tumblr(ENV['consumer_key'], post.tumblr.name, post.tumblr_post_id)
      post.update(:reblog_key => reblog_key)
    end
    TumblrApi.reblog_to_tumblr(@access_token, ENV['tumblr_name'], post.tumblr_post_id, reblog_key)
    post.update(:posted => true)
    Tumblr.
        where(:id => post.tumblr_id).
        update(:last_reblogged_post => DateTime.now)
  end

  # Finder for the next posts
  def next_posts
    Post.
        where('skip is not ?', true).
        where(:posted => false).
        where('tumblr_id not in (?)', skippable_tumblr_ids).
        order(Sequel.desc(:score), Sequel.desc(:fetched))
  end

  def skippable_tumblr_ids
    @skippable_tumblr_ids ||=
        Tumblr.
            select(:id).
            where('tumblrs.last_reblogged_post is not null and tumblrs.last_reblogged_post > ?', (DateTime.now << 1))
  end

  def tags_with_score_in_hash
    Tag.where('value != ?', 0).to_hash(:name, :value)
  end

  def recalculate
    DATABASE.run 'update posts set score = (select sum(tags.value) from tags where tags.name = any(posts.tags))'
  end

end

require_relative 'lib/login'
