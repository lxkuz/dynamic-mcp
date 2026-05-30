module Pdf
  class TocSectionBuilder
    def self.build(page_texts, toc_entries:)
      new(page_texts, toc_entries: toc_entries).build
    end

    def initialize(page_texts, toc_entries:)
      @page_texts = page_texts
      @toc_entries = Array(toc_entries)
      @total_pages = page_texts.length
    end

    def build
      flat = @toc_entries.each_with_index.filter_map do |entry, index|
        title = entry["title"].to_s.strip
        next if title.blank?

        page_start = entry["page"].to_i
        next if page_start < 1

        page_end = end_page_for(index)
        section_pages = @page_texts[(page_start - 1)...page_end] || []

        Books::SectionTreeBuilder::FlatEntry.new(
          title: title,
          plain_text: section_pages.join("\n\n"),
          depth: depth_for(entry),
          position: index,
          page_start: page_start,
          page_end: page_end
        )
      end

      Books::SectionTreeBuilder.build(flat)
    end

    private

    def depth_for(entry)
      level = entry["level"].to_i
      return level - 1 if level.positive?

      Books::SectionDepthInferer.call(entry["title"])
    end

      def end_page_for(index)
        current = @toc_entries[index]
        current_level = current["level"].to_i
        current_level = 1 if current_level <= 0
        current_page = current["page"].to_i

        next_entry = @toc_entries[(index + 1)..]&.find { |entry| entry["level"].to_i.positive? && entry["level"].to_i <= current_level }
        page_end = if next_entry
          [ next_entry["page"].to_i - 1, @total_pages ].min
        else
          @total_pages
        end

        page_end < current_page ? current_page : page_end
      end
  end
end
