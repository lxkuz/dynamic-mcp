require "concurrent"

module Mcp
  class BookMiddleware
    MCP_PATH = %r{\A/books/([^/]+)/mcp/(sse|messages)\z}

    def initialize(app)
      @app = app
      @servers = Concurrent::Map.new
    end

    def call(env)
      request = Rack::Request.new(env)
      match = request.path.match(MCP_PATH)
      return @app.call(env) unless match

      book = Book.find_by(uid: match[1])

      unless book&.ready?
        return json_error(404, "Book not found or not ready")
      end

      server_for(book).call(env)
    end

    private

    def server_for(book)
      cache_key = "#{book.uid}:#{book.updated_at.to_i}"
      @servers[cache_key] ||= build_rack_app(book)
    end

    def build_rack_app(book)
      path_prefix = "/books/#{book.uid}/mcp"
      fallback = ->(_env) { [404, { "Content-Type" => "text/plain" }, ["Not Found"]] }

      FastMcp.rack_middleware(
        fallback,
        name: Mcp::SERVER_NAME,
        version: "1.0.0",
        path_prefix: path_prefix,
        localhost_only: false,
        allowed_origins: allowed_origins,
        logger: Rails.logger
      ) do |server|
        Tools.register_all(server, book)
      end
    end

    def allowed_origins
      origins = ENV.fetch("MCP_ALLOWED_ORIGINS", "localhost,127.0.0.1").split(",").map(&:strip)
      origins << ENV["PUBLIC_HOST"] if ENV["PUBLIC_HOST"].present?
      origins << ENV["RAILS_HOST"] if ENV["RAILS_HOST"].present?
      origins.uniq
    end

    def json_error(status, message)
      [
        status,
        { "Content-Type" => "application/json" },
        [ { error: message }.to_json ]
      ]
    end
  end
end
