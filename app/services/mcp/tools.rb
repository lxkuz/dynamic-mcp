module Mcp
  class Tools
    # fast-mcp treats top-level key "content" as MCP content blocks — never use it in tool results.

    def self.register_all(server, book)
      server.register_tools(
        book_info_tool(book),
        list_toc_tool(book),
        search_toc_tool(book),
        get_page_tool(book),
        get_pages_tool(book),
        get_section_tool(book),
        search_fulltext_tool(book)
      )
    end

    def self.book_info_tool(book)
      mcp = ::Books::McpMetadata.for(book)
      Class.new(FastMcp::Tool) do
        tool_name "book_info"
        description <<~DESC.squish
          Metadata for «#{book.title}» (#{book.author.presence || "author unknown"}).
          #{book.physical_pages? ? "PDF pages: #{book.page_count}." : "Virtual pages: #{book.page_count}, #{book.chars_per_page} chars each."}
          Recommended tools: #{mcp[:recommended_tools].join(", ")}.
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
            structured_toc: mcp[:structured_toc],
            recommended_tools: mcp[:recommended_tools],
            status: book.status
          }
        end
      end
    end

    def self.list_toc_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "list_toc"
        description <<~DESC.squish
          Table of contents tree (section id, title, path, page_start/page_end for PDF chapters).
          #{::Books::McpMetadata.for(book)[:structured_toc] ? "Structured TOC available." : "Flat TOC — prefer search_fulltext for PDF."}
        DESC

        define_method(:call) do
          roots = book.sections.where(parent_id: nil).order(:position)
          { toc: roots.map(&:as_toc_node) }
        end
      end
    end

    def self.search_toc_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "search_toc"
        description "Search section titles and paths (Elasticsearch). Optional context_chars for excerpt."

        arguments do
          required(:query).filled(:string).description("Search query")
          optional(:limit).filled(:integer).description("Max results (default 20)")
          optional(:context_chars).filled(:integer).description("Extra excerpt chars (default 0)")
        end

        define_method(:call) do |query:, limit: 20, context_chars: 0|
          Search::Query.toc(book_id: book.id, query: query, size: limit, context_chars: context_chars)
        end
      end
    end

    def self.get_page_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "get_page"
        description <<~DESC.squish
          #{if book.physical_pages?
              "Text of one PDF page (1..#{book.page_count})."
            else
              "Text of one virtual page (1..#{book.page_count}), ~#{book.chars_per_page} chars."
            end}
          For a range use get_pages.
        DESC

        arguments do
          required(:number).filled(:integer).description("Page number, starting at 1")
        end

        define_method(:call) do |number:|
          page = book.pages.find_by!(number: number)
          {
            page_number: page.number,
            total_pages: book.page_count,
            text: page.readable_text
          }
        end
      end
    end

    def self.get_pages_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "get_pages"
        description <<~DESC.squish
          Text of a contiguous page range (max #{::Books::PageRange::MAX_PAGES} pages).
          #{book.physical_pages? ? "PDF pages 1..#{book.page_count}." : "Virtual pages."}
        DESC

        arguments do
          required(:from).filled(:integer).description("First page number")
          required(:to).filled(:integer).description("Last page number (inclusive)")
        end

        define_method(:call) do |from:, to:|
          ::Books::PageRange.fetch(book, from: from, to: to)
        end
      end
    end

    def self.get_section_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "get_section"
        description "Full text of a TOC section by id (from list_toc). Includes page range for PDF."

        arguments do
          required(:section_id).filled(:integer).description("Section id from list_toc")
        end

        define_method(:call) do |section_id:|
          section = book.sections.find(section_id)
          {
            section_id: section.id,
            title: section.title,
            path: section.path,
            page_start: section.page_start,
            page_end: section.page_end,
            text: section.plain_text
          }
        end
      end
    end

    def self.search_fulltext_tool(book)
      Class.new(FastMcp::Tool) do
        tool_name "search_fulltext"
        description <<~DESC.squish
          Full-text search across #{book.physical_pages? ? "PDF pages" : "virtual pages"} (Elasticsearch).
          Set context_chars for a larger excerpt around the match.
        DESC

        arguments do
          required(:query).filled(:string).description("Search query")
          optional(:limit).filled(:integer).description("Max results (default 20)")
          optional(:context_chars).filled(:integer).description("Excerpt size around match (e.g. 600)")
        end

        define_method(:call) do |query:, limit: 20, context_chars: 0|
          Search::Query.fulltext(
            book_id: book.id,
            query: query,
            size: limit,
            context_chars: context_chars
          )
        end
      end
    end
  end
end
