class CreateWebChannels < ActiveRecord::Migration[7.2]
  def change
    create_table :web_channels do |t|
      t.string :name, null: false
      t.string :external_id, null: false
      t.string :time_zone
      t.string :official_site_url
      t.text :description

      t.timestamps
    end

    add_index :web_channels, :external_id, unique: true
    add_index :web_channels, :name, unique: true
  end
end
