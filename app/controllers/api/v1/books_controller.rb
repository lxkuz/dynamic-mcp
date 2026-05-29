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
          title: book.title,
          author: book.author,
          status: book.status,
          error_message: book.error_message,
          source_format: book.source_format,
          page_count: book.page_count,
          chars_per_page: book.chars_per_page,
          physical_pages: book.physical_pages?,
          mcp_sse_url: mcp_sse_url_for(book),
          mcp_documentation_url: Mcp::DocumentationUrl.for(book),
          created_at: book.created_at
        }
      end

      def mcp_sse_url_for(book)
        host = ENV.fetch("PUBLIC_HOST", "localhost")
        scheme = ENV.fetch("PUBLIC_SCHEME", "http")
        web_port = ENV.fetch("WEB_PORT", "3020")
        "#{scheme}://#{host}:#{web_port}/books/#{book.uid}/mcp/sse"
      end
    end
  end
end
