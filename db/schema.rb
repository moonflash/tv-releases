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

ActiveRecord::Schema[7.2].define(version: 2025_06_17_220000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "countries", force: :cascade do |t|
    t.string "name", null: false
    t.string "shortcode", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shortcode"], name: "index_countries_on_shortcode", unique: true
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "episodes", force: :cascade do |t|
    t.integer "season_number", null: false
    t.integer "episode_number", null: false
    t.date "airdate"
    t.integer "runtime"
    t.text "summary"
    t.string "external_id", null: false
    t.bigint "show_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_episodes_on_external_id", unique: true
    t.index ["show_id", "season_number", "episode_number"], name: "index_episodes_on_show_season_episode", unique: true
    t.index ["show_id"], name: "index_episodes_on_show_id"
  end

  create_table "networks", force: :cascade do |t|
    t.string "name", null: false
    t.string "external_id", null: false
    t.bigint "country_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["country_id"], name: "index_networks_on_country_id"
    t.index ["external_id"], name: "index_networks_on_external_id", unique: true
    t.index ["name"], name: "index_networks_on_name", unique: true
  end

  create_table "releases", force: :cascade do |t|
    t.date "air_date", null: false
    t.time "air_time", null: false
    t.bigint "episode_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["air_date", "air_time"], name: "index_releases_on_air_date_and_air_time"
    t.index ["episode_id", "air_date", "air_time"], name: "index_releases_on_episode_date_time", unique: true
    t.index ["episode_id"], name: "index_releases_on_episode_id"
  end

  create_table "shows", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.string "show_type"
    t.string "official_site_url"
    t.text "genres"
    t.decimal "vote", precision: 3, scale: 1
    t.string "external_id", null: false
    t.bigint "network_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_shows_on_external_id", unique: true
    t.index ["network_id"], name: "index_shows_on_network_id"
    t.index ["title"], name: "index_shows_on_title"
  end

  add_foreign_key "episodes", "shows"
  add_foreign_key "networks", "countries"
  add_foreign_key "releases", "episodes"
  add_foreign_key "shows", "networks"
end
