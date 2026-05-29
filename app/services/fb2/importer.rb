module Fb2
  class Importer
    def self.call(book, io)
      new(book, io).call
    end

    def initialize(book, io)
      @book = book
      @io = io
    end

    def call
      @book.update!(status: "processing", error_message: nil)

      parsed = Parser.parse(@io)
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
