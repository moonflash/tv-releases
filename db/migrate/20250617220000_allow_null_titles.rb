class AllowNullTitles < ActiveRecord::Migration[7.2]
  def change
    change_column_null :shows, :title, true
  end
end 