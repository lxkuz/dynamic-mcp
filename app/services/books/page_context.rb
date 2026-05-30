module Books
  class PageContext
    DEFAULT_CHARS = 600

    def self.for_page(page, query: nil, chars: DEFAULT_CHARS)
      new(page, query: query, chars: chars).extract
    end

    def initialize(page, query: nil, chars:)
      @page = page
      @query = query.to_s.strip
      @chars = chars
    end

    def extract
      text = @page.readable_text
      return text.truncate(@chars) if @query.blank?

      index = find_match_index(text)
      return text.truncate(@chars) unless index

      start_at = [ index - (@chars / 2), 0 ].max
      excerpt = text[start_at, @chars].to_s
      excerpt = "…#{excerpt}" if start_at.positive?
      excerpt = "#{excerpt}…" if start_at + excerpt.length < text.length
      excerpt
    end

    private

    def find_match_index(text)
      normalized_query = normalize(@query)
      return nil if normalized_query.blank?

      index = normalize(text).index(normalized_query)
      return index if index

      first_token = normalized_query.split(/\s+/).find { |token| token.length >= 4 }
      return nil unless first_token

      normalize(text).index(first_token)
    end

    def normalize(value)
      value.to_s.downcase.gsub(/\s+/, " ")
    end
  end
end
