module Books
  module Import
    class FileSampler
      Window = Data.define(:window_id, :page_from, :page_to, :text, :char_count, :label)

      TOC_KEYWORDS = /
        \b(?:содержание|оглавление|contents|table\ of\ contents)\b
      /ix

      CHAPTER_KEYWORDS = /
        ^(?:глава|chapter|part|часть|раздел)\s+[\dIVXLC]+
      /ix

      MAX_WINDOW_CHARS = 8_000

      def self.call(book, io: nil)
        new(book, io: io).call
      end

      def initialize(book, io: nil)
        @book = book
        @io = io
      end

      def call
        @book.source_file.open do |io|
          head = io.read(64.kilobytes)
          io.rewind
          format = sniff_format(head)
          artifacts = sample_format(io, format, head)
          artifacts.merge(
            source_extension: @book.source_format,
            detected_format: format
          )
        end
      end

      def window_text(window_id, artifacts)
        window = artifacts.fetch(:windows).find { |w| w[:window_id] == window_id }
        raise ArgumentError, "Unknown window_id: #{window_id}" unless window

        window
      end

      private

      def sniff_format(head)
        return "pdf" if head.start_with?("%PDF")
        return "fb2" if head.include?("<FictionBook") || head.include?("fictionbook")

        case @book.source_format
        when "pdf", "fb2" then @book.source_format
        else @book.source_format.presence || "bin"
        end
      end

      def sample_format(io, format, head)
        case format
        when "pdf" then sample_pdf(io)
        when "fb2" then sample_fb2(io)
        else sample_generic(io, head, format)
        end
      end

      def sample_pdf(io)
        reader = PDF::Reader.new(io)
        page_count = reader.page_count
        page_texts = (1..page_count).map { |n| extract_pdf_page(reader, n) }
        outline = pdf_outline(reader)

        windows = []
        windows.concat(percent_windows(page_texts, page_count))
        windows.concat(keyword_windows(page_texts, page_count))

        {
          format: "pdf",
          page_count: page_count,
          outline: outline,
          windows: windows.map(&:to_h),
          metadata: pdf_metadata(reader)
        }
      end

      def sample_fb2(io)
        doc = Nokogiri::XML(io.read)
        sections = doc.xpath("//xmlns:body/xmlns:section", "xmlns" => doc.root.namespace&.href).to_a
        ns = doc.root.namespace&.href

        windows = []
        windows << fb2_window(doc, ns, label: "head")
        windows.concat(fb2_section_windows(sections, ns))

        {
          format: "fb2",
          page_count: nil,
          outline: fb2_outline(sections, ns),
          windows: windows.map(&:to_h),
          metadata: {
            title: doc.at_xpath("//xmlns:book-title", "xmlns" => ns)&.text&.strip,
            author: doc.at_xpath("//xmlns:author/xmlns:first-name", "xmlns" => ns)&.text&.strip
          }
        }
      end

      def sample_generic(io, head, format)
        io.rewind
        tail = read_tail(io, 64.kilobytes)
        middle = read_middle(io, 64.kilobytes)
        text_sample = [ head, middle, tail ].compact.join("\n\n---\n\n")
        printable = text_sample.encode("UTF-8", invalid: :replace, undef: :replace, replace: "?")

        windows = [
          Window.new(
            window_id: "#{format}-head",
            page_from: nil,
            page_to: nil,
            text: truncate(printable[0, MAX_WINDOW_CHARS]),
            char_count: printable.length,
            label: "head"
          ),
          Window.new(
            window_id: "#{format}-tail",
            page_from: nil,
            page_to: nil,
            text: truncate(printable[-MAX_WINDOW_CHARS, MAX_WINDOW_CHARS] || printable),
            char_count: printable.length,
            label: "tail"
          )
        ]

        if printable.match?(TOC_KEYWORDS)
          windows << Window.new(
            window_id: "#{format}-toc-candidate",
            page_from: nil,
            page_to: nil,
            text: truncate(extract_toc_candidate(printable)),
            char_count: printable.length,
            label: "toc_candidate"
          )
        end

        {
          format: format,
          page_count: nil,
          outline: [],
          windows: windows.map(&:to_h),
          metadata: {
            filename: @book.source_file.filename.to_s,
            content_type: @book.source_file.content_type,
            byte_size: @book.source_file.byte_size
          }
        }
      end

      def read_tail(io, size)
        io.seek(-size, IO::SEEK_END)
        io.read
      rescue Errno::EINVAL
        io.rewind
        io.read
      end

      def read_middle(io, size)
        io.rewind
        total = io.size
        return nil if total <= size

        io.seek(total / 2)
        io.read(size)
      end

      def extract_toc_candidate(text)
        lines = text.lines
        start_index = lines.index { |line| line.match?(TOC_KEYWORDS) } || 0
        lines[start_index, 80].join
      end

      def percent_windows(page_texts, page_count)
        labels = {
          "start" => 1,
          "p25" => (page_count * 0.25).floor.clamp(1, page_count),
          "p50" => (page_count * 0.50).floor.clamp(1, page_count),
          "p75" => (page_count * 0.75).floor.clamp(1, page_count),
          "end" => [ page_count - 2, 1 ].max
        }

        labels.map do |label, from|
          to = [ from + 2, page_count ].min
          text = page_texts[(from - 1)..(to - 1)].join("\n\n")
          Window.new(
            window_id: "pdf-#{label}-#{from}-#{to}",
            page_from: from,
            page_to: to,
            text: truncate(text),
            char_count: text.length,
            label: label
          )
        end
      end

      def keyword_windows(page_texts, page_count)
        windows = []
        page_texts.each_with_index do |text, index|
          page_number = index + 1
          next unless text.match?(TOC_KEYWORDS) || text.match?(CHAPTER_KEYWORDS)

          from = [ page_number - 1, 1 ].max
          to = [ page_number + 1, page_count ].min
          chunk = page_texts[(from - 1)..(to - 1)].join("\n\n")
          windows << Window.new(
            window_id: "pdf-kw-#{from}-#{to}",
            page_from: from,
            page_to: to,
            text: truncate(chunk),
            char_count: chunk.length,
            label: "keyword"
          )
        end
        windows.uniq { |w| w.window_id }
      end

      def fb2_window(doc, ns, label:)
        title = doc.at_xpath("//xmlns:book-title", "xmlns" => ns)&.text
        author = doc.at_xpath("//xmlns:author", "xmlns" => ns)&.text
        first_sections = doc.xpath("//xmlns:body/xmlns:section", "xmlns" => ns).first(2)
        text = [ title, author, first_sections.map(&:text).join("\n\n") ].compact.join("\n\n")
        Window.new(
          window_id: "fb2-#{label}",
          page_from: nil,
          page_to: nil,
          text: truncate(text),
          char_count: text.length,
          label: label
        )
      end

      def fb2_section_windows(sections, ns)
        return [] if sections.empty?

        picks = [ 0, sections.length / 2, [ sections.length - 1, 0 ].max ].uniq
        picks.filter_map do |index|
          section = sections[index]
          next unless section

          Window.new(
            window_id: "fb2-section-#{index}",
            page_from: nil,
            page_to: nil,
            text: truncate(section.text),
            char_count: section.text.length,
            label: "section_#{index}"
          )
        end
      end

      def fb2_outline(sections, ns)
        sections.first(40).map.with_index do |section, index|
          {
            title: section.at_xpath("./xmlns:title", "xmlns" => ns)&.text&.strip,
            position: index
          }
        end
      end

      def pdf_outline(reader)
        return [] unless reader.respond_to?(:objects) && reader.objects.respond_to?(:outline)

        reader.objects.outline&.map do |entry|
          { title: entry.title.to_s, page: entry.page_number }
        rescue StandardError
          nil
        end&.compact || []
      rescue StandardError
        []
      end

      def pdf_metadata(reader)
        info = reader.info || {}
        {
          title: info[:Title].to_s.strip.presence,
          author: info[:Author].to_s.strip.presence
        }
      end

      def extract_pdf_page(reader, number)
        reader.page(number).text.to_s.delete("\u0000").strip
      rescue StandardError
        ""
      end

      def truncate(text, limit = MAX_WINDOW_CHARS)
        str = text.to_s
        return str if str.length <= limit

        "#{str[0, limit / 2]}\n\n…\n\n#{str[-limit / 2, limit / 2]}"
      end
    end
  end
end
