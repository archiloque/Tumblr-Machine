require 'typhoeus'

if DEDUPLICATION
  require 'phashion'
end

#migrations
migration 'create tables' do
  database.create_table :tags do
    primary_key :id, :type => Bignum, :null => false
    Text :name, :null => false, :index => true, :unique => true
    DateTime :last_fetch, :null => true
    Boolean :fetch, :null => false, :default => false, :index => true
    Integer :value, :null => false
  end

  database.create_table :tumblrs do
    primary_key :id, :type => Bignum, :null => false
    Text :name, :null => false, :index => true
    Text :url, :null => false, :index => true, :unique => true
    DateTime :last_reblogged_post, :null => true
  end

  database.create_table :posts do
    primary_key :id, :type => Bignum, :null => false
    foreign_key :tumblr_id, :tumblrs
    DateTime :fetched, :null => false, :index => true
    Boolean :posted, :null => true, :index => true, :default => false
    Integer :score, :null => false, :index => true
    Boolean :skip, :null => true, :index => true
    Text :img_url, :null => true
    Integer :height, :null => true
    Integer :width, :null => true
  end

  database.create_table :posts_tags do
    foreign_key :post_id, :posts
    foreign_key :tag_id, :tags
  end
end


if DEDUPLICATION

  migration 'fingerprints column' do
    database.alter_table :posts do
      add_column :fingerprint, 'BIT(64)', :null => true
    end
  end

  migration 'get fingerprints' do
    if database[:posts].count > 0

      # download each image in a temp file to calculate its fingerprint
      hydra = Typhoeus::Hydra.new({:max_concurrency => 20})
      hydra.disable_memoization
      database[:posts].filter('img_url is not null').each do |post|
        request = Typhoeus::Request.new post[:img_url]
        request.on_complete do |response|
          if response.code == 200
            file = Tempfile.new('tumblr-machine')
            begin
              file.write response.body
              file.close
              fingerprint = Phashion::Image.new(file.path).fingerprint
              database[:posts].filter(:id => post[:id]).update({:fingerprint => Sequel::LiteralString.new("B'#{fingerprint.to_s(2).rjust(64, '0')}'")})
            ensure
              file.close
              file.unlink
            end
          end
        end
        hydra.queue request
      end
      hydra.run
    end
  end

  migration 'remove duplicates' do
    if database[:posts].count > 0
      dup = 0
      database[:posts].filter('fingerprint is not null').filter(~{:skip => true}).filter(:posted => false).each do |post|
        if database[:posts].filter('fingerprint is not null').filter('id < ?', post[:id]).filter('hamming(fingerprint, (select fingerprint from posts where id = ?)) >= ?', post[:id], DUPLICATE_LEVEL).count > 0
          database[:posts].filter(:id => post[:id]).update({:skip => true})
          dup += 1
        end
      end
      p "#{dup} duplicates found"
    end
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

