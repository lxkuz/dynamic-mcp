# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_29_140000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "books", force: :cascade do |t|
    t.string "author", default: "", null: false
    t.integer "chars_per_page", default: 1800, null: false
    t.datetime "created_at", null: false
    t.text "error_message"
    t.text "mcp_error_message"
    t.integer "mcp_pid"
    t.integer "mcp_port"
    t.string "mcp_status", default: "stopped", null: false
    t.integer "page_count", default: 0, null: false
    t.string "source_format", default: "fb2", null: false
    t.string "status", default: "pending", null: false
    t.string "title", default: "", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_books_on_uid", unique: true
  end

  create_table "pages", force: :cascade do |t|
    t.integer "book_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.integer "number", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "number"], name: "index_pages_on_book_id_and_number", unique: true
    t.index ["book_id"], name: "index_pages_on_book_id"
  end

  create_table "sections", force: :cascade do |t|
    t.integer "book_id", null: false
    t.datetime "created_at", null: false
    t.integer "depth", default: 0, null: false
    t.integer "parent_id"
    t.string "path", default: "", null: false
    t.text "plain_text"
    t.integer "position", default: 0, null: false
    t.string "title", default: "", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "parent_id", "position"], name: "index_sections_on_book_id_and_parent_id_and_position"
    t.index ["book_id"], name: "index_sections_on_book_id"
    t.index ["parent_id"], name: "index_sections_on_parent_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "pages", "books"
  add_foreign_key "sections", "books"
  add_foreign_key "sections", "sections", column: "parent_id"
end
