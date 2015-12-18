Sequel.migration do
  up do

    create_table :tags do
      primary_key :id, :type => Bignum, :null => false
      Text :name, :null => false, :index => true, :unique => true
      DateTime :last_fetch, :null => true
      TrueClass :fetch, :null => false, :default => false, :index => true
      Integer :value, :null => false
    end

    create_table :tumblrs do
      primary_key :id, :type => Bignum, :null => false
      Text :name, :null => false, :index => true
      Text :url, :null => false, :index => true, :unique => true
      DateTime :last_reblogged_post, :null => true
    end

    create_table :posts do
      primary_key :id, :type => Bignum, :null => false
      foreign_key :tumblr_id, :tumblrs
      DateTime :fetched, :null => false, :index => true
      TrueClass :posted, :null => true, :index => true, :default => false
      Integer :score, :null => false, :index => true
      TrueClass :skip, :null => true, :index => true
      Text :img_url, :null => true
      Integer :height, :null => true
      Integer :width, :null => true
    end

    create_table :posts_tags do
      foreign_key :post_id, :posts, :type => Bignum
      foreign_key :tag_id, :tags
    end

  end
end
