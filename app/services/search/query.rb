module Search
  class Query
    def self.fulltext(book_id:, query:, size: 20)
      new(book_id: book_id, query: query, doc_type: "page", size: size).run
    end

    def self.toc(book_id:, query:, size: 50)
      new(book_id: book_id, query: query, doc_type: "toc", size: size).run
    end

    def initialize(book_id:, query:, doc_type:, size:)
      @book_id = book_id
      @query = query
      @doc_type = doc_type
      @size = size
    end

    def run
      return [] if @query.blank?

      ElasticsearchClient.ensure_index!
      response = ElasticsearchClient.instance.search(
        index: ElasticsearchClient::INDEX,
        body: {
          size: @size,
          query: {
            bool: {
              must: [
                { term: { book_id: @book_id.to_s } },
                { term: { doc_type: @doc_type } },
                {
                  multi_match: {
                    query: @query,
                    fields: @doc_type == "toc" ? %w[title^3 path^2 body] : %w[body],
                    type: "best_fields",
                    fuzziness: "AUTO"
                  }
                }
              ]
            }
          },
          highlight: {
            fields: {
              body: {},
              title: {},
              path: {}
            }
          }
        }
      )

      response["hits"]["hits"].map { |hit| format_hit(hit) }
    end

    private

    def format_hit(hit)
      source = hit["_source"]
      {
        score: hit["_score"],
        highlight: hit["highlight"],
        section_id: source["section_id"],
        page_number: source["page_number"],
        title: source["title"],
        path: source["path"],
        snippet: snippet_for(hit)
      }
    end

    def snippet_for(hit)
      highlights = hit["highlight"]
      return highlights.values.flatten.first if highlights.present?

      body = hit.dig("_source", "body").to_s
      body.truncate(280)
    end
  end
end
