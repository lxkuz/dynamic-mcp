module Mcp
  module DocumentationUrl
    module_function

    def for(book)
      Books::PublicUrl.path("/books/#{book.uid}/mcp")
    end
  end
end
