module Books
  class McpMetadata
    def self.for(book)
      new(book).as_json
    end

    def initialize(book)
      @book = book
    end

    def as_json
      {
        structured_toc: structured_toc?,
        recommended_tools: recommended_tools
      }
    end

    private

    def structured_toc?
      return true if @book.fb2?

      @book.sections.where.not(page_start: nil).count > 1
    end

    def recommended_tools
      tools = %w[book_info search_fulltext get_page]

      if structured_toc?
        tools.insert(1, "list_toc")
        tools.insert(2, "search_toc")
        tools << "get_section"
      else
        tools << "list_toc"
      end

      tools << "get_pages" if @book.physical_pages?
      tools
    end
  end
end
