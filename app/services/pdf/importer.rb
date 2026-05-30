module Pdf
  class Importer
    def self.call(book, io, toc_entries: nil)
      new(book, io, toc_entries: toc_entries).call
    end

    def initialize(book, io, toc_entries: nil)
      @book = book
      @io = io
      @toc_entries = toc_entries
    end

    def call
      @book.update!(status: "processing", error_message: nil)

      parsed = Parser.parse(@io, toc_entries: @toc_entries)
      Books::PersistParsedContent.call(@book, parsed)
      Search::Indexer.index_book!(@book)
      @book.update!(status: "ready")
      @book
    rescue StandardError => e
      @book.update!(status: "failed", error_message: e.message)
      raise
    end
  end
end
