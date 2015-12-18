Sequel.migration do
  up do

    alter_table :posts do
      add_column :img_saved, TrueClass, :null => false, :default => false
    end

  end

end
