class AddResponseToChats < ActiveRecord::Migration[7.1]
  def change
    add_column :chats, :response, :text
  end
end
