module Books
  module Import
    class ParserScriptPrompt
      def call
        <<~PROMPT.strip
          You write a Ruby parser script for a book file.
          Reads ARGV[0], prints JSON to stdout: puts JSON.generate(...)

          Allowed requires: json, pdf-reader, nokogiri, rexml, zip, zlib only.
          No eval, shell, network, file writes, or raise.

          ## WRONG output (never do this)

          "pages": [
            {"page_number": 1, "content_preview": "first 200 chars..."},
            {"page_number": 2, "content_preview": "..."}
          ]

          ## CORRECT output

          {
            "title": "Book title",
            "author": "Author name",
            "pages": [
              "Full plain text of PDF page 1 including all paragraphs...",
              "Full plain text of PDF page 2..."
            ],
            "sections": [
              {
                "title": "Chapter 1",
                "plain_text": "Optional chapter body or title",
                "depth": 1,
                "position": 1,
                "path": "1",
                "page_start": 1,
                "page_end": 10,
                "children": []
              }
            ]
          }

          pages MUST be an array of STRINGS — full page text, not objects, not previews.

          ## Example Ruby script for PDF (follow this pattern)

          require 'json'
          require 'pdf-reader'

          path = ARGV[0]
          reader = PDF::Reader.new(path)
          info = reader.info rescue {}
          title = info[:Title].to_s
          author = info[:Author].to_s

          pages = (1..reader.page_count).map do |n|
            reader.page(n).text.to_s.delete("\\u0000")
          end

          sections = []
          # Flat list with depth from toc entry level (level 1 => depth 0, level 2 => depth 1).
          # Post-processor builds nested children automatically.
          toc_entries.each_with_index do |entry, idx|
            next_entry = toc_entries[idx + 1]
            page_start = entry["page"]
            page_end = next_entry ? next_entry["page"] - 1 : reader.page_count
            sections << {
              "title" => entry["title"],
              "plain_text" => "",
              "depth" => entry["level"].to_i - 1,
              "position" => idx + 1,
              "path" => (idx + 1).to_s,
              "page_start" => page_start,
              "page_end" => page_end,
              "children" => []
            }
          end

          puts JSON.generate(
            "title" => title,
            "author" => author,
            "pages" => pages,
            "sections" => sections
          )

          Adapt for FB2/XML using nokogiri, or EPUB using zip + nokogiri. Use input JSON fields: chapter_detection_strategy,
          toc_entries, build_toc_while_parsing, canonical_snippet, output_rules, reference_scripts.

          ## Example Ruby script for FB2 (follow this pattern)

          require 'json'
          require 'nokogiri'

          path = ARGV[0]
          doc = Nokogiri::XML(File.read(path))
          doc.remove_namespaces!

          title = doc.at_xpath('//description/title-info/book-title')&.text.to_s.strip
          author = doc.at_xpath('//description/title-info/author')&.text.to_s.strip

          body = doc.xpath('//body').find { |b| b['name'].to_s.strip.empty? } || doc.at_xpath('//body')
          paragraphs = body.xpath('.//p').map { |p| p.text.strip }.reject(&:empty?)
          reading_text = paragraphs.join("\\n\\n")

          CHARS = 1800
          pages = []
          paragraphs.each do |para|
            if pages.empty? || pages.last.length + para.length + 2 > CHARS
              pages << para
            else
              pages[-1] = pages.last + "\\n\\n" + para
            end
          end
          pages = [reading_text] if pages.empty? && reading_text.present?

          sections = body.xpath('./section').map.with_index do |sec, idx|
            {
              "title" => sec.at_xpath('./title')&.text.to_s.strip,
              "plain_text" => sec.xpath('./p').map { |p| p.text.strip }.join("\\n\\n"),
              "depth" => 0,
              "position" => idx,
              "path" => (idx + 1).to_s,
              "children" => []
            }
          end

          puts JSON.generate("title" => title, "author" => author, "pages" => pages, "sections" => sections)

          ## Example Ruby script for EPUB (follow this pattern)

          require 'json'
          require 'zip'
          require 'nokogiri'

          path = ARGV[0]
          title = ''
          author = ''
          texts = []

          Zip::File.open(path) do |zip|
            opf_entry = zip.glob('**/*.opf').first
            next unless opf_entry

            opf = Nokogiri::XML(opf_entry.get_input_stream.read)
            opf.remove_namespaces!
            title = opf.at_xpath('//metadata/title')&.text.to_s.strip
            author = opf.at_xpath('//metadata/creator')&.text.to_s.strip

            manifest = {}
            opf.xpath('//manifest/item').each { |item| manifest[item['id']] = item['href'].to_s }
            opf.xpath('//spine/itemref').each do |itemref|
              href = manifest[itemref['idref']].to_s
              next if href.empty?
              entry = zip.find_entry(href) || zip.glob('**/' + href.split('/').last).first
              next unless entry
              html = Nokogiri::HTML(entry.get_input_stream.read)
              text = html.css('body').text.to_s.gsub(/\\s+/, ' ').strip
              texts << text unless text.empty?
            end
          end

          CHARS = 1800
          pages = []
          texts.each do |para|
            if pages.empty? || pages.last.length + para.length + 2 > CHARS
              pages << para
            else
              pages[-1] = pages.last + "\\n\\n" + para
            end
          end
          pages = [texts.join("\\n\\n")] if pages.empty? && texts.any?

          puts JSON.generate('title' => title, 'author' => author, 'pages' => pages, 'sections' => [])

          When reference_scripts is provided — proven working parsers for the same file format.
          Adapt the closest reference to current book structure (do not copy blindly).

          Reply ONLY with Ruby source code (no markdown fences).
        PROMPT
      end
    end
  end
end
