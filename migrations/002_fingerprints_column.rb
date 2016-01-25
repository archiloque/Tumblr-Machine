Sequel.migration do
  up do

    alter_table :posts do
      add_column :fingerprint, 'BIT(64)', :null => true
    end

  end
end
