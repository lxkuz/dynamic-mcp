class CreateBookImports < ActiveRecord::Migration[8.1]
  def change
    create_table :book_imports do |t|
      t.references :book, null: false, foreign_key: true, index: { unique: true }
      t.string :status, null: false, default: "queued"
      t.integer :iteration, null: false, default: 0
      t.string :mode, null: false, default: "ai"
      t.json :sampler_artifacts
      t.json :toc_discovery
      t.json :structure_analysis
      t.text :generated_script
      t.string :script_sha256
      t.text :last_run_stdout
      t.text :last_run_stderr
      t.json :validation_report
      t.json :quality_report
      t.json :llm_usage, null: false, default: {}
      t.text :error_message
      t.datetime :started_at
      t.datetime :finished_at

      t.timestamps
    end

    create_table :book_import_events do |t|
      t.references :book_import, null: false, foreign_key: true
      t.string :step, null: false
      t.string :status, null: false
      t.integer :iteration, null: false, default: 0
      t.float :duration_seconds
      t.json :payload
      t.text :message

      t.timestamps
    end

    add_index :book_import_events, %i[book_import_id created_at]
  end
end
