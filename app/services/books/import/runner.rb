require "digest"
require "json"
require "open3"
require "tempfile"

module Books
  module Import
    class Runner
      def self.call(book)
        new(book).call
      end

      def initialize(book)
        @book = book
      end

      def call
        import = @book.book_import || @book.create_book_import!(
          status: "queued",
          mode: Import.ai_enabled? ? "ai" : "legacy"
        )

        if import.mode == "legacy" || !Import.ai_enabled?
          unless LegacyImporter.supported?(@book.source_format)
            raise ArgumentError,
                  "Legacy import supports only fb2 and pdf; got #{@book.source_format}"
          end

          run_legacy!(import)
        else
          Orchestrator.call(@book)
        end
      end

      private

      def run_legacy!(import)
        import.update!(status: "running", started_at: Time.current, mode: "legacy")
        import.log_event!(step: "legacy_import", status: "started")
        LegacyImporter.call(@book)
        import.succeed!
        import.log_event!(step: "legacy_import", status: "ok")
      rescue StandardError => e
        import.fail!(e.message)
        raise
      end
    end
  end
end
