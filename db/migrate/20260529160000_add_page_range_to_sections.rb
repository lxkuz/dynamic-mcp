class AddPageRangeToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :page_start, :integer
    add_column :sections, :page_end, :integer
  end
end
