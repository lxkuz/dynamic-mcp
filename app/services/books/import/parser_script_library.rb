module Books
  module Import
    class ParserScriptLibrary
      MAX_REFERENCES = 2
      MAX_SCRIPT_CHARS = 10_000

      def self.record_success!(book:, book_import:, script:, stats: {})
        new(book: book, book_import: book_import, script: script, stats: stats).record_success!
      end

      def self.references_for(source_format, limit: MAX_REFERENCES)
        new(source_format: source_format).references_for(limit: limit)
      end

      def initialize(book: nil, book_import: nil, script: nil, stats: {}, source_format: nil)
        @book = book
        @book_import = book_import
        @script = script
        @stats = stats
        @source_format = source_format || book&.source_format
      end

      def record_success!
        return if @script.blank? || @source_format.blank?

        sample = ParserScriptSample.find_or_initialize_by(
          source_format: @source_format.to_s,
          script_sha256: Digest::SHA256.hexdigest(@script.to_s)
        )
        sample.assign_attributes(
          script: @script.to_s,
          book: @book,
          book_import: @book_import,
          page_count: @stats[:page_count],
          section_count: @stats[:section_count]
        )
        sample.save!
        sample
      end

      def references_for(limit: MAX_REFERENCES)
        ParserScriptSample.for_format(@source_format).recent_first.limit(limit).map do |sample|
          {
            source_format: sample.source_format,
            page_count: sample.page_count,
            section_count: sample.section_count,
            saved_at: sample.updated_at,
            script: sample.script.to_s.truncate(MAX_SCRIPT_CHARS)
          }
        end
      end
    end
  end
end
