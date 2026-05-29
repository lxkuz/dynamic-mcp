module Mcp
  module DocumentationUrl
    module_function

    def for(book)
      host = ENV.fetch("PUBLIC_HOST", "localhost")
      scheme = ENV.fetch("PUBLIC_SCHEME", "http")
      web_port = ENV.fetch("WEB_PORT", "3020")
      "#{scheme}://#{host}:#{web_port}/books/#{book.uid}/mcp"
    end
  end
end
