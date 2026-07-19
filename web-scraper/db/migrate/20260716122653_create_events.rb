class CreateEvents < ActiveRecord::Migration[7.0]
  def change
    create_table :events do |t|
      t.string :name
      t.date :event_date
      t.string :city
      t.string :result_url
      t.string :clax_file_url
      t.datetime :scraped_at

      t.timestamps
    end
  end
end
