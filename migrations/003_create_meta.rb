Sequel.migration do
  up do

    create_table :metas do
      primary_key :id, :type => Bignum, :null => false
      Text :key, :null => false, :index => true
      Text :value, :null => false, :index => true
    end
  end


end
