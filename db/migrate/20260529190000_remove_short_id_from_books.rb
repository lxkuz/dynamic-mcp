class RemoveShortIdFromBooks < ActiveRecord::Migration[8.0]
  def change
    remove_index :books, :short_id, if_exists: true
    remove_column :books, :short_id, :string, if_exists: true
  end
end
