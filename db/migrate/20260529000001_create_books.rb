class CreateBooks < ActiveRecord::Migration[8.1]
  def change
    create_table :books do |t|
      t.string :title, null: false, default: ""
      t.string :author, null: false, default: ""
      t.string :status, null: false, default: "pending"
      t.text :error_message
      t.integer :page_count, null: false, default: 0
      t.integer :chars_per_page, null: false, default: 1800

      t.timestamps
    end
  end
end
