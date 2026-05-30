class CreateParserScriptSamples < ActiveRecord::Migration[8.1]
  def change
    create_table :parser_script_samples do |t|
      t.string :source_format, null: false
      t.text :script, null: false
      t.string :script_sha256, null: false
      t.references :book, foreign_key: true
      t.references :book_import, foreign_key: true
      t.integer :page_count
      t.integer :section_count
      t.timestamps
    end

    add_index :parser_script_samples, %i[source_format script_sha256], unique: true
    add_index :parser_script_samples, %i[source_format updated_at]
  end
end
