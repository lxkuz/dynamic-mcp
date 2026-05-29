module Mcp
  class DocumentationPresenter
    ToolDoc = Data.define(:name, :description, :arguments)

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
      "dynamic-mcp-book-#{@book.uid}"
    end

    def cursor_config_json
      {
        mcpServers: {
          server_name => {
            url: sse_url
          }
        }
      }.to_json
    end

    def tools
      [
        ToolDoc.new("book_info", "Метаданные книги", "—"),
        ToolDoc.new("list_toc", "Всё оглавление (дерево)", "—"),
        ToolDoc.new("search_toc", "Поиск по оглавлению", "query, limit?"),
        ToolDoc.new(
          "get_page",
          @book.physical_pages? ? "Текст страницы PDF" : "Текст виртуальной страницы",
          "number"
        ),
        ToolDoc.new("search_fulltext", "Полнотекстовый поиск", "query, limit?")
      ]
    end
  end
end
