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

      def self.fb2_snippet
        <<~RUBY.strip
          # FB2: File.read is allowed; do NOT use pdf-reader.
          require 'nokogiri'
          path = ARGV[0]
          doc = Nokogiri::XML(File.read(path))
          doc.remove_namespaces!
          body = doc.xpath('//body').find { |b| b['name'].to_s.strip.empty? } || doc.at_xpath('//body')
          reading = body.xpath('.//p').map { |p| p.text.strip }.reject(&:empty?).join("\\n\\n")
          CHARS = 1800
          pages = []
          reading.split(/\\n{2,}/).each do |para|
            next if para.empty?
            if pages.empty? || pages.last.length + para.length + 2 > CHARS
              pages << para
            else
              pages[-1] = pages.last + "\\n\\n" + para
            end
          end
          pages = [reading] if pages.empty? && reading.present?
        RUBY
      end
    end
  end
end
