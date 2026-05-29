module Books
  class PersistParsedContent
    def self.call(book, parsed)
      new(book, parsed).call
    end

    def initialize(book, parsed)
      @book = book
      @parsed = parsed
    end

    def call
      Book.transaction do
        @book.sections.destroy_all
        @book.pages.destroy_all

        @book.update!(
          title: @parsed.title,
          author: @parsed.author,
          chars_per_page: Book::CHARS_PER_PAGE
        )

        persist_sections(@parsed.sections)
        persist_pages
        @book.update!(page_count: @book.pages.count)
      end
    end

    private

    def persist_sections(nodes, parent: nil)
      nodes.each do |node|
        section = @book.sections.create!(
          parent: parent,
          title: node.title.presence || "Без названия",
          path: node.path,
          depth: node.depth,
          position: node.position,
          plain_text: node.plain_text
        )
        persist_sections(node.children, parent: section)
      end
    end

    def persist_pages
      page_contents = @parsed.pages.presence || TextPaginator.paginate(
        @parsed.reading_text,
        chars_per_page: @book.chars_per_page
      )

      page_contents.each_with_index do |content, index|
        @book.pages.create!(number: index + 1, content: sanitize_page_text(content))
      end
    end

    def sanitize_page_text(text)
      text.to_s.delete("\u0000")
    end
  end
end
