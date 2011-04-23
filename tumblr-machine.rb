require 'rubygems'
require 'bundler'
Bundler.setup

require 'logger'
require 'nokogiri'
require 'open-uri'
require 'sinatra/base'

require 'sinatra'
require 'sinatra/sequel'

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


  #migrations
  migration 'create tables' do
    database.create_table :tags do
      primary_key :id, :type => Integer, :null => false
      Text :name, :null => false, :index => true, :unique => true
      DateTime :last_fetch_date, :null => true
      Integer :score, :null => true
    end

    database.create_table :tumblrs do
      primary_key :id, :type => Integer, :null => false
      Text :name, :null => false, :index => true, :unique => true
      DateTime :last_post_date, :null => true
    end

    database.create_table :post do
      primary_key :id, :type => Integer, :null => false
      foreign_key :tumblr_id, :tumblrs
      DateTime :last_fetch_date, :null => false
      Boolean :posted, :null => true, :index => true
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
  class Tubmlr < Sequel::Model
    one_to_many :posts
  end

  class Post < Sequel::Model
    many_to_many :tags
    many_to_one :tumblr
  end

  get '/' do

  end

end
