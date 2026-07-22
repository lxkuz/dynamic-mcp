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

      def self.epub_snippet
        <<~RUBY.strip
          # EPUB is ZIP: require zip (rubyzip). Do NOT parse ZIP bytes manually.
          require 'zip'
          require 'nokogiri'
          path = ARGV[0]
          title = ""
          author = ""
          html_texts = []
          Zip::File.open(path) do |zip|
            opf_entry = zip.glob("**/*.opf").first
            next unless opf_entry

            opf = Nokogiri::XML(opf_entry.get_input_stream.read)
            opf.remove_namespaces!
            title = opf.at_xpath("//metadata/title")&.text.to_s.strip
            author = opf.at_xpath("//metadata/creator")&.text.to_s.strip
            opf_dir = opf_entry.name.include?("/") ? opf_entry.name.rpartition("/").first : ""
            manifest = {}
            opf.xpath("//manifest/item").each do |item|
              manifest[item["id"]] = item["href"].to_s
            end
            opf.xpath("//spine/itemref").each do |itemref|
              href = manifest[itemref["idref"]].to_s
              next if href.empty?

              entry_name = opf_dir.empty? ? href : "\#{opf_dir}/\#{href}"
              entry = zip.find_entry(entry_name) || zip.find_entry(href) || zip.glob("**/\#{href.split('/').last}").first
              next unless entry

              doc = Nokogiri::HTML(entry.get_input_stream.read)
              text = doc.css("body").text.to_s.gsub(/\\s+/, " ").strip
              html_texts << text unless text.empty?
            end
          end
          reading = html_texts.join("\\n\\n")
          CHARS = 1800
          pages = []
          html_texts.each do |para|
            next if para.empty?
            if pages.empty? || pages.last.length + para.length + 2 > CHARS
              pages << para
            else
              pages[-1] = pages.last + "\\n\\n" + para
            end
          end
          pages = [reading] if pages.empty? && !reading.empty?
        RUBY
      end
    end
  end
end
