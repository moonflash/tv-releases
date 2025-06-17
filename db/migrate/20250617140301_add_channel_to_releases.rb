class AddChannelToReleases < ActiveRecord::Migration[7.2]
  def change
    add_reference :releases, :channel, null: true, foreign_key: true
  end
end
