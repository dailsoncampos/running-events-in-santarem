# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_07_16_122700) do
  create_table "events", force: :cascade do |t|
    t.string "name"
    t.date "event_date"
    t.string "city"
    t.string "result_url"
    t.string "clax_file_url"
    t.datetime "scraped_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "runners", force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "position"
    t.string "bib_number"
    t.string "name"
    t.string "club"
    t.string "gender"
    t.string "category"
    t.string "finish_time"
    t.string "average_pace"
    t.integer "points"
    t.integer "laps"
    t.string "best_lap"
    t.string "distance"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_runners_on_event_id"
  end

  add_foreign_key "runners", "events"
end
