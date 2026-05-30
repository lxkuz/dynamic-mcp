module Books
  class CreateFromUpload
    LEGACY_FORMATS = %w[fb2 pdf].freeze

    def self.call(uploaded)
      new(uploaded).call
    end

    def initialize(uploaded)
      @uploaded = uploaded
    end

    def call
      source_format = detect_source_format!
      ensure_importable!(source_format)

      book = Book.create!(status: "processing", source_format: source_format)
      book.source_file.attach(@uploaded)
      book.create_book_import!(
        status: "queued",
        mode: import_mode_for(source_format)
      )

      ImportBookJob.perform_async(book.id)
      book
    end

    private

    def detect_source_format!
      filename = @uploaded.original_filename.to_s
      extension = File.extname(filename).downcase.delete_prefix(".")
      extension = extension.gsub(/[^a-z0-9]/, "")
      return extension if extension.present?

      mime = @uploaded.content_type.to_s
      return "pdf" if mime.include?("pdf")
      return "fb2" if mime.include?("xml")
      return "txt" if mime.start_with?("text/")

      "bin"
    end

    def ensure_importable!(source_format)
      return if Books::Import.ai_enabled?
      return if LEGACY_FORMATS.include?(source_format)

      raise ArgumentError,
            "Формат «#{source_format}» требует AI-импорт. Укажите DEEPSEEK_API_KEY и AI_IMPORT_ENABLED=true."
    end

    def import_mode_for(source_format)
      return "legacy" if !Books::Import.ai_enabled? && LEGACY_FORMATS.include?(source_format)

      "ai"
    end
  end
end
