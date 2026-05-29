class CreatePages < ActiveRecord::Migration[8.1]
  def change
    create_table :pages do |t|
      t.references :book, null: false, foreign_key: true
      t.integer :number, null: false
      t.text :content, null: false

      t.timestamps
    end

    add_index :pages, %i[book_id number], unique: true
  end
end
