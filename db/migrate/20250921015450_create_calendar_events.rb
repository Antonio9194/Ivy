class CreateCalendarEvents < ActiveRecord::Migration[7.1]
  def change
    create_table :calendar_events do |t|
      t.string :title
      t.text :description
      t.datetime :start_time
      t.datetime :end_time
      t.datetime :alert
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
