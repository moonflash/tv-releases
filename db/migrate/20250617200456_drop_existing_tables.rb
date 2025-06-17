class DropExistingTables < ActiveRecord::Migration[7.2]
  def up
    drop_table :releases if table_exists?(:releases)
    drop_table :channels if table_exists?(:channels)
    drop_table :countries if table_exists?(:countries)
  end

  def down
    # We're starting fresh, so no need to recreate old structure
    raise ActiveRecord::IrreversibleMigration
  end
end
