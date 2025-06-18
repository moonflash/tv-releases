class AddWebChannelToShows < ActiveRecord::Migration[7.2]
  def change
    add_reference :shows, :web_channel, foreign_key: true

    change_column_null :shows, :network_id, true
  end
end
