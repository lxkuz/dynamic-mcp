module Books
  ParsedDocument = Data.define(:title, :author, :sections, :reading_text, :pages)

  class TextPaginator
    def self.paginate(text, chars_per_page: Book::CHARS_PER_PAGE)
      return [] if text.blank?

      chunks = []
      buffer = +""
      text.split(/\n{2,}/).each do |paragraph|
        paragraph = paragraph.strip
        next if paragraph.empty?

        if buffer.length + paragraph.length + 2 > chars_per_page && buffer.present?
          chunks << buffer.strip
          buffer = +""
        end

        if paragraph.length > chars_per_page
          chunks << buffer.strip if buffer.present?
          buffer = +""
          paragraph.scan(/.{1,#{chars_per_page}}/m) { |part| chunks << part.strip }
          next
        end

        buffer << "\n\n" if buffer.present?
        buffer << paragraph
      end

      chunks << buffer.strip if buffer.present?
      chunks.reject(&:blank?)
    end
  end
end
