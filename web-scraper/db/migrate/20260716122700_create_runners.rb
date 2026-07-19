class CreateRunners < ActiveRecord::Migration[7.0]
  def change
    create_table :runners do |t|
      t.references :event, null: false, foreign_key: true
      t.integer :position
      t.string :bib_number
      t.string :name
      t.string :club
      t.string :gender
      t.string :category
      t.string :finish_time
      t.string :average_pace
      t.integer :points
      t.integer :laps
      t.string :best_lap
      t.string :distance

      t.timestamps
    end
  end
end
