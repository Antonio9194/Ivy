class MakeUserIdNotNullInRecords < ActiveRecord::Migration[7.1]
  def change
    change_column_null :records, :user_id, false
  end
end