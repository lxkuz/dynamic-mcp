class AddSourceFormatToBooks < ActiveRecord::Migration[8.1]
  def change
    add_column :books, :source_format, :string, default: "fb2", null: false
  end
end
