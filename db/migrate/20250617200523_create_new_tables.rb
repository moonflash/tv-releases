class CreateNewTables < ActiveRecord::Migration[7.2]
  def change
    # Countries table
    create_table :countries do |t|
      t.string :name, null: false
      t.string :shortcode, null: false
      t.timestamps
    end
    add_index :countries, :shortcode, unique: true

    # Networks table (renamed from channels)
    create_table :networks do |t|
      t.string :name, null: false
      t.string :external_id, null: false
      t.references :country, null: true, foreign_key: true
      t.timestamps
    end
    add_index :networks, :name, unique: true
    add_index :networks, :external_id, unique: true

    # Shows table
    create_table :shows do |t|
      t.string :title, null: false
      t.text :description
      t.string :show_type
      t.string :official_site_url
      t.text :genres
      t.decimal :vote, precision: 3, scale: 1
      t.string :external_id, null: false
      t.references :network, null: false, foreign_key: true
      t.timestamps
    end
    add_index :shows, :external_id, unique: true
    add_index :shows, :title

    # Episodes table
    create_table :episodes do |t|
      t.integer :season_number, null: false
      t.integer :episode_number, null: false
      t.date :airdate
      t.integer :runtime
      t.text :summary
      t.string :external_id, null: false
      t.references :show, null: false, foreign_key: true
      t.timestamps
    end
    add_index :episodes, :external_id, unique: true
    add_index :episodes, [ :show_id, :season_number, :episode_number ], unique: true, name: 'index_episodes_on_show_season_episode'

    # Releases table (simplified)
    create_table :releases do |t|
      t.date :air_date, null: false
      t.time :air_time, null: false
      t.references :episode, null: false, foreign_key: true
      t.timestamps
    end
    add_index :releases, [ :air_date, :air_time ]
    add_index :releases, [ :episode_id, :air_date, :air_time ], unique: true, name: 'index_releases_on_episode_date_time'
  end
end
