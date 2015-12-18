class TumblrMachine

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