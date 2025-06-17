class CreateReleases < ActiveRecord::Migration[7.2]
  def change
    create_table :releases do |t|
      t.date    :air_date, null: false
      t.time    :air_time, null: false
      t.string  :title,    null: false
      t.integer :season_number, null: false
      t.integer :episode_number, null: false
      t.string  :episode_title, null: false

      t.timestamps
    end

    add_index :releases, [ :air_date, :air_time ]
  end
end
