#migrations
migration 'create tables' do
  database.create_table :tags do
    primary_key :id, :type => Integer, :null => false
    Text :name, :null => false, :index => true, :unique => true
    DateTime :last_fetch, :null => true
    Boolean :fetch, :null => false, :default => false, :index => true
    Integer :value, :null => true
  end

  database.create_table :tumblrs do
    primary_key :id, :type => Integer, :null => false
    Text :name, :null => false, :index => true, :unique => true
    Text :url, :null => false, :index => true, :unique => true
    DateTime :last_reblogged_post, :null => true
  end

  database.create_table :posts do
    primary_key :id, :type => Integer, :null => false
    foreign_key :tumblr_id, :tumblrs
    DateTime :fetched, :null => false
    Boolean :posted, :null => true, :index => true, :default => false
    Integer :score, :null => true, :index => true
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

class Tumblr < Sequel::Model
  one_to_many :posts
end

class Post < Sequel::Model
  many_to_many :tags
  many_to_one :tumblr
end
