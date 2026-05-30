module Search
  class Query
    def self.fulltext(book_id:, query:, size: 20, context_chars: 0)
      new(book_id: book_id, query: query, doc_type: "page", size: size, context_chars: context_chars).run
    end

    def self.toc(book_id:, query:, size: 50, context_chars: 0)
      new(book_id: book_id, query: query, doc_type: "toc", size: size, context_chars: context_chars).run
    end

    def initialize(book_id:, query:, doc_type:, size:, context_chars: 0)
      @book_id = book_id
      @query = query
      @doc_type = doc_type
      @size = size
      @context_chars = context_chars.to_i
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

      response["hits"]["hits"].map { |hit| enrich_hit(format_hit(hit)) }
    end

    private

    def enrich_hit(hit)
      return hit if @context_chars <= 0

      if hit[:page_number]
        page = Page.joins(:book).find_by(books: { id: @book_id }, number: hit[:page_number])
        hit[:context] = ::Books::PageContext.for_page(page, query: @query, chars: @context_chars) if page
      elsif hit[:section_id]
        section = Section.find_by(id: hit[:section_id], book_id: @book_id)
        hit[:context] = section.plain_text.to_s.truncate(@context_chars) if section
      end

      hit
    end

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
