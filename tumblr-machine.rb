require 'rubygems'
require 'bundler'
Bundler.setup

require 'logger'
require 'nokogiri'
require 'open-uri'
require 'sinatra/base'

require 'sinatra'
require 'sinatra/sequel'

require 'rack-flash'

Sequel::Model.raise_on_save_failure = true
require 'erb'

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

  #migrations
  migration 'create tables' do
    database.create_table :tags do
      primary_key :id, :type => Integer, :null => false
      Text :name, :null => false, :index => true, :unique => true
      DateTime :last_fetch, :null => true
      Integer :value, :null => true
    end

    database.create_table :tumblrs do
      primary_key :id, :type => Integer, :null => false
      Text :name, :null => false, :index => true, :unique => true
      DateTime :last_post, :null => true
    end

    database.create_table :posts do
      primary_key :id, :type => Integer, :null => false
      foreign_key :tumblr_id, :tumblrs
      DateTime :last_fetch, :null => false
      Boolean :posted, :null => true, :index => true
      Integer :score, :null => false, :index => true
    end

    database.create_table :posts_tags do
      foreign_key :post_id, :posts
      foreign_key :tag_id, :tags
    end
  end

  #models
  class Tag < Sequel::Model
    many_to_many :posts
  end

  #models
  class Tumblr < Sequel::Model
    one_to_many :posts
  end

  class Post < Sequel::Model
    many_to_many :tags
    many_to_one :tumblr
  end

  # admin
  get '/' do
    @tags = database['select tags.name n, tags.last_fetch l, tags.value v, count(posts.id) c from tags, posts_tags, posts ' +
                         'where tags.id = posts_tags.tag_id and posts_tags.post_id = posts.id' +
                         ' order by tags.value desc, tags.last_fetch desc']
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
          if delta == 0
            flash[:notice] = 'Tag value not changed'
          else
            tag.value = value
            tag.update(:value => value)
            Post.filter('posts.id in (select posts_tags.post_id from posts_tags where posts_tags.tag_id = ?)', tag.id).update(:score => :score + delta)
            flash[:notice] = 'Tag updated'
          end
        elsif value
          Tag.create(:name => name, :value => value)
          flash[:notice] = 'Tag added'
        else
          flash[:notice] = 'Tag did not exist and value is 0 so nothing done'
        end

      redirect '/'
    end
  end

end
