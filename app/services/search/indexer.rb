module Search
  class Indexer
    def self.index_book!(book)
      new(book).index!
    end

    def self.remove_book!(book_id)
      ElasticsearchClient.instance.delete_by_query(
        index: ElasticsearchClient::INDEX,
        body: { query: { term: { book_id: book_id.to_s } } }
      )
    end

    def initialize(book)
      @book = book
    end

    def index!
      ElasticsearchClient.ensure_index!
      self.class.remove_book!(@book.id)

      bulk_body = []
      @book.sections.find_each do |section|
        bulk_body << { index: { _index: ElasticsearchClient::INDEX } }
        bulk_body << toc_document(section)
      end

      @book.pages.find_each do |page|
        bulk_body << { index: { _index: ElasticsearchClient::INDEX } }
        bulk_body << page_document(page)
      end

      return if bulk_body.empty?

      ElasticsearchClient.instance.bulk(body: bulk_body, refresh: true)
    end

    private

    def toc_document(section)
      {
        book_id: @book.id.to_s,
        doc_type: "toc",
        section_id: section.id.to_s,
        title: section.title,
        path: section.path,
        body: [ section.title, section.path, section.plain_text ].join("\n")
      }
    end

    def page_document(page)
      {
        book_id: @book.id.to_s,
        doc_type: "page",
        page_number: page.number,
        body: page.content
      }
    end
  end
end
