module Mcp
  class Tools
    def self.register_all(server, book)
      server.register_tools(
        book_info_tool(book),
        list_toc_tool(book),
        search_toc_tool(book),
        get_page_tool(book),
        search_fulltext_tool(book)
      )
    end

    def self.book_info_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "book_info"
        description <<~DESC.squish
          Metadata for «#{book.title}» (#{book.author.presence || "author unknown"}).
          #{book.physical_pages? ? "PDF pages: #{book.page_count}." : "Virtual pages: #{book.page_count}, #{book.chars_per_page} chars each."}
        DESC

        define_method(:call) do
          {
            uid: book.uid,
            title: book.title,
            author: book.author,
            source_format: book.source_format,
            page_count: book.page_count,
            chars_per_page: book.chars_per_page,
            pagination: book.physical_pages? ? "physical_pdf_pages" : "virtual_chars",
            status: book.status
          }
        end
      end
    end

    def self.list_toc_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "list_toc"
        description "Full table of contents as a nested tree of sections."

        define_method(:call) do
          roots = book.sections.where(parent_id: nil).order(:position)
          { toc: roots.map(&:as_toc_node) }
        end
      end
    end

    def self.search_toc_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "search_toc"
        description "Search section titles and paths in the table of contents (Elasticsearch)."

        arguments do
          required(:query).filled(:string).description("Search query")
          optional(:limit).filled(:integer).description("Max results (default 20)")
        end

        define_method(:call) do |query:, limit: 20|
          Search::Query.toc(book_id: book.id, query: query, size: limit)
        end
      end
    end

    def self.get_page_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "get_page"
        description <<~DESC.squish
          #{if book.physical_pages?
              "Text of PDF page (1..#{book.page_count})."
            else
              "Text of a virtual page (1..#{book.page_count}). Pages are ~#{book.chars_per_page} characters, split by paragraphs."
            end}
        DESC

        arguments do
          required(:number).filled(:integer).description("Page number, starting at 1")
        end

        define_method(:call) do |number:|
          page = book.pages.find_by!(number: number)
          {
            page_number: page.number,
            total_pages: book.page_count,
            # Do not use key "content" — fast-mcp treats it as MCP content blocks (array).
            text: page.readable_text
          }
        end
      end
    end

    def self.search_fulltext_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "search_fulltext"
        description "Full-text search across all virtual pages (Elasticsearch)."

        arguments do
          required(:query).filled(:string).description("Search query")
          optional(:limit).filled(:integer).description("Max results (default 20)")
        end

        define_method(:call) do |query:, limit: 20|
          Search::Query.fulltext(book_id: book.id, query: query, size: limit)
        end
      end
    end
  end
end
