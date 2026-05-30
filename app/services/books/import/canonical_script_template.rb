module Books
  module Import
    class CanonicalScriptTemplate
      def self.pdf_snippet
        <<~RUBY.strip
          # CRITICAL: pages is an array of STRINGS — full text of each PDF page, not objects.
          pages = (1..reader.page_count).map do |n|
            reader.page(n).text.to_s.delete("\\u0000")
          end
        RUBY
      end
    end
  end
end
