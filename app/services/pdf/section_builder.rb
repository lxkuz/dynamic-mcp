module Pdf
  class SectionBuilder
    def self.build(page_texts, book_title:)
      new(page_texts, book_title: book_title).build
    end

    def initialize(page_texts, book_title:)
      @page_texts = page_texts
      @book_title = book_title
      @total_pages = page_texts.length
    end

    def build
      chapters = ChapterDetector.detect(@page_texts)
      return [ single_section ] if chapters.empty?

      flat = chapters.map.with_index do |chapter, index|
        page_start = chapter.page_number
        page_end = end_page_for(index, chapters)
        section_pages = @page_texts[(page_start - 1)...page_end]

        Books::SectionTreeBuilder::FlatEntry.new(
          title: chapter.title,
          plain_text: section_pages.join("\n\n"),
          depth: chapter.depth,
          position: index,
          page_start: page_start,
          page_end: page_end
        )
      end

      Books::SectionTreeBuilder.build(flat)
    end

    private

    def end_page_for(index, chapters)
      next_start = chapters[index + 1]&.page_number
      return @total_pages unless next_start

      [ next_start - 1, @total_pages ].min
    end

    def single_section
      reading_text = @page_texts.join("\n\n")
      Books::ParsedSection.new(
        title: @book_title,
        plain_text: reading_text,
        depth: 0,
        position: 0,
        path: @book_title,
        children: [],
        page_start: @total_pages.positive? ? 1 : nil,
        page_end: @total_pages.positive? ? @total_pages : nil
      )
    end
  end
end
