class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.references :book, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :sections }
      t.integer :position, null: false, default: 0
      t.integer :depth, null: false, default: 0
      t.string :title, null: false, default: ""
      t.string :path, null: false, default: ""
      t.text :plain_text

      t.timestamps
    end

    add_index :sections, %i[book_id parent_id position]
  end
end
