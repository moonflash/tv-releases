class AddUrlAndExternalIdToReleases < ActiveRecord::Migration[7.2]
  def change
    add_column :releases, :url, :string
    add_column :releases, :external_id, :string
  end
end
