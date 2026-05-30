module Books
  module Import
    class JsonMapper
      def self.to_parsed_document(data)
        new(data).to_parsed_document
      end

      def initialize(data)
        @data = data.deep_stringify_keys
      end

      def to_parsed_document
        parsed = ScriptOutputNormalizer.call(@data)
        Books::ParsedDocument.new(
          title: parsed["title"].presence || "Без названия",
          author: parsed["author"].to_s,
          sections: Books::SectionHierarchyNormalizer.call(parsed["sections"] || []),
          reading_text: parsed["reading_text"],
          pages: parsed["pages"]
        )
      end
    end
  end
end
