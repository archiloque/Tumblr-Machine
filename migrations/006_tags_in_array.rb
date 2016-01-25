Sequel.migration do
  up do

    alter_table :posts do
      add_column :tags, 'text[]', :null => true
    end

    drop_table :posts_tags
    self << 'delete from tags where "value" = 0 and "fetch" = FALSE'

  end
end
