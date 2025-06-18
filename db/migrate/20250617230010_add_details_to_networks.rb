class AddDetailsToNetworks < ActiveRecord::Migration[7.2]
  def change
    add_column :networks, :time_zone, :string
    add_column :networks, :official_site_url, :string
    add_column :networks, :description, :text
  end
end
