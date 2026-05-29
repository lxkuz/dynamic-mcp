class AddUidAndMcpToBooks < ActiveRecord::Migration[8.1]
  def up
    add_column :books, :uid, :string
    add_column :books, :mcp_port, :integer
    add_column :books, :mcp_pid, :integer
    add_column :books, :mcp_status, :string, null: false, default: "stopped"
    add_column :books, :mcp_error_message, :text

    backfill_uids

    change_column_null :books, :uid, false
    add_index :books, :uid, unique: true
  end

  def down
    remove_index :books, :uid
    remove_column :books, :mcp_error_message
    remove_column :books, :mcp_status
    remove_column :books, :mcp_pid
    remove_column :books, :mcp_port
    remove_column :books, :uid
  end

  private

  def backfill_uids
    select_all("SELECT id FROM books").each do |row|
      uid = generate_uid
      execute("UPDATE books SET uid = #{quote(uid)} WHERE id = #{row['id']}")
    end
  end

  def generate_uid
    loop do
      candidate = SecureRandom.urlsafe_base64(32)
      break candidate unless select_value("SELECT 1 FROM books WHERE uid = #{quote(candidate)}")
    end
  end
end
