class AddLowerTitleIndexToShows < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute <<-SQL
      CREATE INDEX CONCURRENTLY IF NOT EXISTS index_shows_on_lower_title ON shows (lower(title));
    SQL
  end

  def down
    remove_index :shows, name: :index_shows_on_lower_title, algorithm: :concurrently if index_exists?(:shows, name: :index_shows_on_lower_title)
  end
end
