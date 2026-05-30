module Pdf
  class ChapterDetector
    Entry = Data.define(:title, :page_number, :depth)

    CHAPTER_LINE = /\A(?:глава|chapter)\s+[\dIVXLCА-Я]+(?:\s*[-–—:]\s*.+)?\z/i
    NUMBERED_HEADING = /\A\d+(?:\.\d+)*\.?\s+\S/

    def self.detect(page_texts)
      new(page_texts).detect
    end

    def initialize(page_texts)
      @page_texts = page_texts
    end

    def detect
      entries = []
      @page_texts.each_with_index do |text, index|
        title = heading_title(text)
        next if title.blank?

        page_number = index + 1
        next if entries.last && (page_number - entries.last.page_number) < 2

        entries << Entry.new(
          title: title,
          page_number: page_number,
          depth: Books::SectionDepthInferer.call(title)
        )
      end
      entries
    end

    private

    def heading_title(text)
      lines = text.to_s.lines.map(&:strip).reject(&:blank?).first(6)
      return nil if lines.empty?

      lines.each_with_index do |line, index|
        if line.match?(CHAPTER_LINE)
          subtitle = lines[index + 1]
          return subtitle.present? ? "#{line} — #{subtitle}" : line
        end

        return line if line.match?(NUMBERED_HEADING) && line.length <= 120
      end

      nil
    end
  end
end
