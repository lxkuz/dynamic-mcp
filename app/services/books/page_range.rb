module Books
  class PageRange
    MAX_PAGES = 20

    def self.fetch(book, from:, to:)
      new(book, from: from, to: to).fetch
    end

    def initialize(book, from:, to:)
      @book = book
      @from = from
      @to = to
    end

    def fetch
      validate_range!

      pages = @book.pages.where(number: @from..@to).order(:number)
      {
        from: @from,
        to: @to,
        total_pages: @book.page_count,
        pages: pages.map { |page| page_payload(page) }
      }
    end

    private

    def validate_range!
      raise ArgumentError, "from must be >= 1" if @from < 1
      raise ArgumentError, "to must be >= from" if @to < @from
      raise ArgumentError, "to exceeds page_count (#{@book.page_count})" if @to > @book.page_count

      return if (@to - @from + 1) <= MAX_PAGES

      raise ArgumentError, "range too large (max #{MAX_PAGES} pages per request)"
    end

    def page_payload(page)
      {
        page_number: page.number,
        text: page.readable_text
      }
    end
  end
end
