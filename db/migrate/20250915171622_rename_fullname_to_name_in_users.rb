class RenameFullnameToNameInUsers < ActiveRecord::Migration[7.0]
  def change
    rename_column :users, :full_name, :name
  end
end