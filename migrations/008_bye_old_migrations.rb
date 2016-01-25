Sequel.migration do
  up do

    drop_table? :migrations

  end
end
