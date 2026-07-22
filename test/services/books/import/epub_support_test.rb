require "test_helper"
require "open3"
require "zip"

module Books
  module Import
    class EpubSupportTest < ActiveSupport::TestCase
      test "parser and fix prompts advertise zip allowlist" do
        author = ParserScriptPrompt.new.call
        fixer = ScriptFixPrompt.new.call

        assert_match(/zip/, author)
        assert_match(/zip/, fixer)
        assert_match(/EPUB/, author)
      end

      test "structure analysis prompt has EPUB example with zip" do
        prompt = StructureAnalysisPrompt.new.call
        assert_match(/"detected_format": "epub"/, prompt)
        assert_match(/"zip"/, prompt)
      end

      test "orchestrator output rules mention Zip::File for epub" do
        book = Book.new(source_format: "epub", status: "processing", uid: "test-uid")
        import = BookImport.new(book: book, mode: "ai", status: "scripting")
        orchestrator = Orchestrator.allocate
        orchestrator.instance_variable_set(:@book, book)
        orchestrator.instance_variable_set(:@import, import)

        rules = orchestrator.send(:output_rules_for, { "detected_format" => "epub" })
        assert rules.any? { |r| r.include?("Zip::File") }
        assert rules.any? { |r| r.include?("require 'zip'") }

        snippet = orchestrator.send(:canonical_snippet_for, { "detected_format" => "epub" })
        assert_includes snippet, "require 'zip'"
      end

      test "minimal epub parser script extracts pages when rubyzip is available" do
        epub_path = write_minimal_epub!
        script = <<~RUBY
          require "json"
          require "zip"
          require "nokogiri"

          path = ARGV[0]
          title = ""
          author = ""
          texts = []

          Zip::File.open(path) do |zip|
            opf_entry = zip.glob("**/*.opf").first
            raise "missing opf" unless opf_entry

            opf = Nokogiri::XML(opf_entry.get_input_stream.read)
            opf.remove_namespaces!
            title = opf.at_xpath("//metadata/title")&.text.to_s.strip
            author = opf.at_xpath("//metadata/creator")&.text.to_s.strip

            manifest = {}
            opf.xpath("//manifest/item").each { |item| manifest[item["id"]] = item["href"].to_s }
            opf.xpath("//spine/itemref").each do |itemref|
              href = manifest[itemref["idref"]].to_s
              next if href.empty?
              entry = zip.find_entry(href) || zip.glob("**/" + href.split("/").last).first
              next unless entry
              html = Nokogiri::HTML(entry.get_input_stream.read)
              text = html.css("body").text.to_s.gsub(/\\s+/, " ").strip
              texts << text unless text.empty?
            end
          end

          pages = texts
          pages = ["fallback"] if pages.empty?
          puts JSON.generate("title" => title, "author" => author, "pages" => pages, "sections" => [])
        RUBY

        assert ScriptStaticValidator.call(script).safe

        stdout, stderr, status = Open3.capture3("ruby", "-e", script, epub_path)
        assert_equal 0, status.exitstatus, stderr
        payload = JSON.parse(stdout)
        assert_equal "Minimal EPUB", payload["title"]
        assert_equal "Test Author", payload["author"]
        assert payload["pages"].any? { |p| p.include?("Hello from EPUB chapter") }
      ensure
        FileUtils.rm_f(epub_path) if epub_path
      end

      private

      def write_minimal_epub!
        path = Rails.root.join("tmp", "minimal-#{SecureRandom.hex(4)}.epub").to_s
        FileUtils.mkdir_p(File.dirname(path))

        Zip::File.open(path, Zip::File::CREATE) do |zip|
          zip.get_output_stream("mimetype") { |f| f.write("application/epub+zip") }
          zip.get_output_stream("META-INF/container.xml") do |f|
            f.write(<<~XML)
              <?xml version="1.0"?>
              <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
                <rootfiles>
                  <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
                </rootfiles>
              </container>
            XML
          end
          zip.get_output_stream("OEBPS/content.opf") do |f|
            f.write(<<~XML)
              <?xml version="1.0"?>
              <package xmlns="http://www.idpf.org/2007/opf" version="2.0" unique-identifier="bookid">
                <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                  <dc:title>Minimal EPUB</dc:title>
                  <dc:creator>Test Author</dc:creator>
                  <dc:identifier id="bookid">test-epub-1</dc:identifier>
                </metadata>
                <manifest>
                  <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
                </manifest>
                <spine>
                  <itemref idref="chap1"/>
                </spine>
              </package>
            XML
          end
          zip.get_output_stream("OEBPS/chap1.xhtml") do |f|
            f.write(<<~XHTML)
              <?xml version="1.0" encoding="UTF-8"?>
              <html xmlns="http://www.w3.org/1999/xhtml">
                <head><title>Chapter 1</title></head>
                <body><p>Hello from EPUB chapter</p></body>
              </html>
            XHTML
          end
        end

        path
      end
    end
  end
end
