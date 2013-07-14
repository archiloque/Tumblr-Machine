require 'typhoeus'

if DEDUPLICATION
  require 'phashion'
end

class TumblrMachine

  #migrations
  migration 'create tables' do
    database.create_table :tags do
      primary_key :id, :type => Bignum, :null => false
      Text :name, :null => false, :index => true, :unique => true
      DateTime :last_fetch, :null => true
      TrueClass :fetch, :null => false, :default => false, :index => true
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
      TrueClass :posted, :null => true, :index => true, :default => false
      Integer :score, :null => false, :index => true
      TrueClass :skip, :null => true, :index => true
      Text :img_url, :null => true
      Integer :height, :null => true
      Integer :width, :null => true
    end

    database.create_table :posts_tags do
      foreign_key :post_id, :posts, :type => Bignum
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
        database[:posts].where('img_url is not null').each do |post|
          request = Typhoeus::Request.new post[:img_url]
          request.on_complete do |response|
            if response.code == 200
              file = Tempfile.new('tumblr-machine')
              begin
                file.write response.body
                file.close
                fingerprint = Phashion::Image.new(file.path).fingerprint
                database[:posts].where(:id => post[:id]).update({:fingerprint => Sequel.lit("B'#{fingerprint.to_s(2).rjust(64, '0')}'")})
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
        database[:posts].
            where('fingerprint is not null').
            where(~{:skip => true}).
            where(:posted => false).each do |post|
          if database[:posts].
              where('fingerprint is not null').
              where('id < ?', post[:id]).
              where('hamming(fingerprint, (select fingerprint from posts where id = ?)) >= ?', post[:id], DUPLICATE_LEVEL).
              exists
            database[:posts].
                where(:id => post[:id]).
                update({:skip => true})
            dup += 1
          end
        end
        p "#{dup} duplicates found"
      end
    end

  end

  migration 'create meta' do
    database.create_table :metas do
      primary_key :id, :type => Bignum, :null => false
      Text :key, :null => false, :index => true
      Text :value, :null => false, :index => true
    end
  end

  migration 'reblog_key' do
    database.alter_table :posts do
      add_column :reblog_key, String, :null => true, :text => true
    end
  end

  migration 'saved images' do
    database.alter_table :posts do
      add_column :img_saved, TrueClass, :null => false, :default => false
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
    many_to_many :tags, :order => [Sequel.desc(:value), Sequel.asc(:name)]
    many_to_one :tumblr

    def before_destroy
      super
      remove_all_tags
    end

    attr_accessor :loaded_tags
    attr_accessor :loaded_tumblr

  end

  class Meta < Sequel::Model

  end
end