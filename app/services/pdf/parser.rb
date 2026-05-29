module Pdf
  class Parser
    class NoExtractableTextError < StandardError
      def initialize
        super("В PDF нет извлекаемого текста (возможно, отсканированный документ без OCR)")
      end
    end

    ANONYMOUS_METADATA = /\A\(anonymous\)\z/i

    def self.parse(io)
      new(io).parse
    end

    def initialize(io)
      @reader = PDF::Reader.new(io)
    rescue PDF::Reader::EncryptedPDFError
      raise ArgumentError, "PDF защищён паролем"
    rescue PDF::Reader::MalformedPDFError => e
      raise ArgumentError, "Повреждённый или неподдерживаемый PDF: #{e.message}"
    end

    def parse
      page_texts = extract_page_texts
      raise NoExtractableTextError if page_texts.all?(&:blank?)

      title = document_title(page_texts)
      author = document_author
      reading_text = page_texts.join("\n\n")

      Books::ParsedDocument.new(
        title: title,
        author: author,
        sections: [
          Books::ParsedSection.new(
            title: title,
            plain_text: reading_text,
            depth: 0,
            position: 0,
            path: title,
            children: []
          )
        ],
        reading_text: reading_text,
        pages: page_texts
      )
    end

    private

    def extract_page_texts
      (1..@reader.page_count).map { |number| normalize_text(@reader.page(number).text) }
    end

    def document_title(page_texts)
      metadata_string(:Title).then { |value| value unless anonymous_label?(value) } ||
        title_from_first_page(page_texts) ||
        "Untitled"
    end

    def document_author
      metadata_string(:Author).then { |value| value unless anonymous_label?(value) } || ""
    end

    def metadata_string(key)
      value = @reader.info[key]
      return "" if value.blank?

      value.to_s.strip
    end

    def anonymous_label?(value)
      value.blank? || value.match?(ANONYMOUS_METADATA)
    end

    def title_from_first_page(page_texts)
      page_texts.first.to_s.lines.map(&:strip).find { |line| line.present? && line.length <= 200 }
    end

    def normalize_text(text)
      text.to_s
        .encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        .delete("\u0000")
        .tr("\f", "\n")
        .gsub(/\r\n?/, "\n")
        .gsub(/[ \t]+\n/, "\n")
        .gsub(/\n[ \t]+/, "\n")
        .gsub(/[ \t]{2,}/, " ")
        .gsub(/\n{3,}/, "\n\n")
        .strip
    end
  end
end
