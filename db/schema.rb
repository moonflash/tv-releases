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

ActiveRecord::Schema[7.2].define(version: 2025_06_17_165441) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "channels", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_channels_on_name", unique: true
  end

  create_table "countries", force: :cascade do |t|
    t.string "name"
    t.string "shortcode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shortcode"], name: "index_countries_on_shortcode", unique: true
  end

  create_table "releases", force: :cascade do |t|
    t.date "air_date", null: false
    t.time "air_time", null: false
    t.string "title", null: false
    t.integer "season_number", null: false
    t.integer "episode_number", null: false
    t.string "episode_title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "channel_id"
    t.string "url"
    t.string "external_id"
    t.bigint "country_id"
    t.index ["air_date", "air_time"], name: "index_releases_on_air_date_and_air_time"
    t.index ["channel_id"], name: "index_releases_on_channel_id"
    t.index ["country_id"], name: "index_releases_on_country_id"
  end

  add_foreign_key "releases", "channels"
  add_foreign_key "releases", "countries"
end
