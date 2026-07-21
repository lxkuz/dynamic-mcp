module Books
  module Import
    class OutputValidator
      SCHEMA_PATH = Rails.root.join("config/books/import_output_schema.json")

      Result = Data.define(:ok, :errors, :warnings, :stats) do
        def to_h
          { ok: ok, errors: errors, warnings: warnings, stats: stats }
        end
      end

      def self.call(json, expected_page_count: nil)
        new(json, expected_page_count: expected_page_count).call
      end

      def initialize(json, expected_page_count: nil)
        @json = json
        @expected_page_count = expected_page_count
      end

      def call
        errors = schema_errors
        warnings = []
        stats = {}

        if errors.empty?
          stats = build_stats
          errors.concat(business_errors(stats))
          warnings.concat(business_warnings(stats))
        end

        if errors.empty? && stats[:avg_chars_per_page].to_i.positive? && stats[:avg_chars_per_page] < ScriptOutputNormalizer::MIN_PAGE_CHARS
          warnings << "pages look truncated (avg #{stats[:avg_chars_per_page]} chars) — use full page text, not previews"
          errors << "page text too short — output full page content as strings" if stats[:avg_chars_per_page] < 250
        end

        Result.new(ok: errors.empty?, errors: errors, warnings: warnings, stats: stats)
      end

      private

      def schema_errors
        schema = JSON.parse(File.read(SCHEMA_PATH))
        schema.delete("$schema")
        normalized = ScriptOutputNormalizer.call(@json)
        JSON::Validator.fully_validate(schema, normalized)
      end

      def build_stats
        pages = normalize_page_texts(@json["pages"] || [])
        sections = flatten_sections(@json["sections"] || [])
        {
          page_count: pages.length,
          section_count: sections.length,
          avg_chars_per_page: pages.empty? ? 0 : (pages.sum(&:length) / pages.length),
          empty_pages: pages.count(&:blank?)
        }
      end

      def normalize_page_texts(pages)
        ScriptOutputNormalizer.call({ "pages" => pages })["pages"]
      end

      def business_errors(stats)
        errors = []
        pages = normalize_page_texts(@json["pages"] || [])
        reading = @json["reading_text"].to_s

        errors << "pages and reading_text are both empty" if pages.empty? && reading.blank?
        errors << "title is blank" if @json["title"].to_s.strip.blank?
        errors << "all pages are empty" if pages.any? && stats[:empty_pages] == pages.length
        errors
      end

      def business_warnings(stats)
        warnings = []
        pages = normalize_page_texts(@json["pages"] || [])
        warnings << "no sections in output" if stats[:section_count].zero?
        warnings << "many empty pages (#{stats[:empty_pages]})" if stats[:empty_pages].to_i > 3
        if @expected_page_count && pages.any? && pages.length != @expected_page_count
          warnings << "page count #{pages.length} != expected #{@expected_page_count}"
        end
        warnings
      end

      def flatten_sections(nodes)
        nodes.flat_map do |node|
          [ node ] + flatten_sections(node["children"] || [])
        end
      end
    end
  end
end
