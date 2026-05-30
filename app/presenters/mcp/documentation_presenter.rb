module Mcp
  class DocumentationPresenter
    ToolDoc = Data.define(:name, :description, :arguments)

    # Suggested key for ~/.cursor/mcp.json (any short name works; keep under Cursor's 60-char tool limit).
    CURSOR_CONFIG_KEY = "dm"

    def initialize(book, base_url:)
      @book = book
      @base_url = base_url.to_s.chomp("/")
    end

    def sse_url
      "#{@base_url}/books/#{@book.uid}/mcp/sse"
    end

    def messages_url
      "#{@base_url}/books/#{@book.uid}/mcp/messages"
    end

    def server_name
      Mcp::SERVER_NAME
    end

    def cursor_config_json
      {
        mcpServers: {
          CURSOR_CONFIG_KEY => {
            url: sse_url
          }
        }
      }.to_json
    end

    def tools
      [
        ToolDoc.new("book_info", "Метаданные книги", "—"),
        ToolDoc.new("list_toc", "Всё оглавление (дерево)", "—"),
        ToolDoc.new("search_toc", "Поиск по оглавлению", "query, limit?, context_chars?"),
        ToolDoc.new(
          "get_page",
          @book.physical_pages? ? "Текст страницы PDF" : "Текст виртуальной страницы",
          "number"
        ),
        ToolDoc.new("get_pages", "Диапазон страниц", "from, to"),
        ToolDoc.new("get_section", "Текст секции по id", "section_id"),
        ToolDoc.new("search_fulltext", "Полнотекстовый поиск", "query, limit?, context_chars?")
      ]
    end
  end
end
