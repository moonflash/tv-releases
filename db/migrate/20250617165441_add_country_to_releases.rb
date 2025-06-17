class AddCountryToReleases < ActiveRecord::Migration[7.2]
  def change
    add_reference :releases, :country, null: true, foreign_key: true
  end
end
