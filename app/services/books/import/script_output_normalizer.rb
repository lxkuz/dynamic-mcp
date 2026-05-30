module Books
  module Import
    class ScriptOutputNormalizer
      MIN_PAGE_CHARS = 50

      def self.call(json)
        new(json).call
      end

      def initialize(json)
        @json = json.deep_stringify_keys
      end

      def call
        pages = normalize_pages(@json["pages"])
        normalized = {
          "title" => @json["title"].presence || "Без названия",
          "author" => @json["author"].to_s,
          "pages" => pages,
          "sections" => @json["sections"] || []
        }
        reading = @json["reading_text"]
        normalized["reading_text"] = reading if reading.is_a?(String) && reading.present?
        normalized
      end

      def truncated_pages?(pages)
        return false if pages.blank?

        pages.all? { |text| text.length <= 250 }
      end

      private

      def normalize_pages(pages)
        return [] if pages.blank?

        Array(pages).map { |page| normalize_page(page) }.reject(&:blank?)
      end

      def normalize_page(page)
        text = case page
               when String then page
               when Hash
                 page["text"] || page["content"] || page["body"] ||
                   page["plain_text"] || page["content_preview"]
               else
                 page.to_s
               end

        text.to_s.delete("\u0000").strip
      end
    end
  end
end
