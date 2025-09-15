class CreateAttachments < ActiveRecord::Migration[7.1]
  def change
    create_table :attachments do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :file
      t.string :file_type

      t.timestamps
    end
  end
end
