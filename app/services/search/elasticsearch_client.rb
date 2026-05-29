module Search
  class ElasticsearchClient
    INDEX = "dynamic_mcp_books"

    class << self
      def instance
        @instance ||= ::Elasticsearch::Client.new(
          url: Rails.application.config.elasticsearch_url,
          log: Rails.env.development?
        )
      end

      def ensure_index!
        client = instance
        return if client.indices.exists(index: INDEX)

        client.indices.create(
          index: INDEX,
          body: {
            mappings: {
              properties: {
                book_id: { type: "keyword" },
                doc_type: { type: "keyword" },
                section_id: { type: "keyword" },
                page_number: { type: "integer" },
                title: { type: "text", analyzer: "standard" },
                path: { type: "text", analyzer: "standard" },
                body: { type: "text", analyzer: "standard" }
              }
            }
          }
        )
      end
    end
  end
end
