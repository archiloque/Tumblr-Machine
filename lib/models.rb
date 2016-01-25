require 'sequel/extensions/pg_array'
require 'sequel/extensions/pg_array_ops'

Sequel.extension :core_extensions
Sequel.extension :pg_array_ops

class TumblrMachine
  DATABASE.extension :pg_array

  class Tag < Sequel::Model
  end

  class Tumblr < Sequel::Model
    one_to_many :posts
  end

  class Post < Sequel::Model
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