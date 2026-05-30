module Api
  module V1
    class BooksController < Api::BaseController
      def index
        books = Book.order(created_at: :desc)
        render json: books.map { |book| book_json(book) }
      end

      def show
        book = Book.find_by!(uid: params[:uid])
        render json: book_json(book)
      end

      def create
        book = ::Books::CreateFromUpload.call(params.require(:file))
        render json: book_json(book), status: :created
      rescue ArgumentError, StandardError => e
        render json: { error: e.message }, status: :unprocessable_entity
      end

      private

      def book_json(book)
        {
          uid: book.uid,
          mcp_server_name: Mcp::SERVER_NAME,
          title: book.title,
          author: book.author,
          status: book.status,
          error_message: book.error_message,
          source_format: book.source_format,
          page_count: book.page_count,
          chars_per_page: book.chars_per_page,
          physical_pages: book.physical_pages?,
          structured_toc: ::Books::McpMetadata.for(book)[:structured_toc],
          recommended_tools: ::Books::McpMetadata.for(book)[:recommended_tools],
          mcp_sse_url: mcp_sse_url_for(book),
          mcp_documentation_url: Mcp::DocumentationUrl.for(book),
          import: import_json(book),
          created_at: book.created_at
        }
      end

      def import_json(book)
        import = book.book_import
        return nil unless import

        {
          status: import.status,
          mode: import.mode,
          iteration: import.iteration,
          error_message: import.error_message,
          started_at: import.started_at,
          finished_at: import.finished_at
        }
      end

      def mcp_sse_url_for(book)
        Books::PublicUrl.path("/books/#{book.uid}/mcp/sse")
      end
    end
  end
end
