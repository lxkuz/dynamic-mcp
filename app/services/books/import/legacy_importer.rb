module Books
  module Import
    class LegacyImporter
      SUPPORTED = %w[fb2 pdf].freeze

      def self.supported?(format)
        SUPPORTED.include?(format.to_s)
      end

      def self.call(book)
        new(book).call
      end

      def initialize(book)
        @book = book
      end

      def call
        @book.update!(status: "processing", error_message: nil)

        @book.source_file.open do |io|
          case @book.source_format
          when "fb2"
            Fb2::Importer.call(@book, io)
          when "pdf"
            toc_entries = @book.book_import&.toc_discovery&.dig("toc_entries")
            Pdf::Importer.call(@book, io, toc_entries: toc_entries)
          else
            raise ArgumentError, "Unsupported format: #{@book.source_format}"
          end
        end
      end
    end
  end
end
