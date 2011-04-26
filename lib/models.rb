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

migration 'larger columns for posts ids' do
  database.alter_table :posts do
     set_column_type :id, Bignum
  end
  database.alter_table :posts_tags do
     set_column_type :post_id, Bignum
  end
end

migration 'no null tags score' do
  database.run 'update tags set value = 0 where value is null'
  database.alter_table :tags do
     set_column_allow_null :value, false
  end
  database.run 'update posts set score = 0 where score is null'
  database.alter_table :posts do
    set_column_allow_null :score, false
  end
end

migration 'skipping posts' do
  database.alter_table :posts do
    add_column :skip, :boolean, :null => true, :index => true
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
  many_to_many :tags, :order => [:value.desc, :name.asc]
  many_to_one :tumblr

  def before_destroy
    super
    remove_all_tags
  end
end
