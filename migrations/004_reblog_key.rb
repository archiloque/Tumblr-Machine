Sequel.migration do
  up do

    alter_table :posts do
      add_column :reblog_key, String, :null => true, :text => true
    end
  end

end
