module Books
  class CreateFromUpload
    SUPPORTED_EXTENSIONS = {
      ".fb2" => "fb2",
      ".pdf" => "pdf"
    }.freeze

    def self.call(uploaded)
      new(uploaded).call
    end

    def initialize(uploaded)
      @uploaded = uploaded
    end

    def call
      source_format = detect_source_format!

      book = Book.create!(status: "pending", source_format: source_format)
      book.source_file.attach(@uploaded)

      book.source_file.open do |io|
        import_book(book, io, source_format)
      end

      book.reload
    end

    private

    def detect_source_format!
      extension = File.extname(@uploaded.original_filename.to_s.downcase)
      format = SUPPORTED_EXTENSIONS[extension]
      return format if format

      raise ArgumentError, "Поддерживаются только файлы .fb2 и .pdf"
    end

    def import_book(book, io, source_format)
      case source_format
      when "fb2"
        Fb2::Importer.call(book, io)
      when "pdf"
        Pdf::Importer.call(book, io)
      else
        raise ArgumentError, "Неподдерживаемый формат: #{source_format}"
      end
    end
  end
end
