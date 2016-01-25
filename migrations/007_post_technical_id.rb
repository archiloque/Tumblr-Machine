Sequel.migration do
  up do

    alter_table :posts do
      add_column :tumblr_post_id, Bignum, :null => true
    end
    self << 'update posts set tumblr_post_id = id'
    alter_table :posts do
      set_column_not_null :tumblr_post_id
      add_index :tumblr_post_id, :unique => true
    end

  end
end
