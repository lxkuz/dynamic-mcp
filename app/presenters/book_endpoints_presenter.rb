class BookEndpointsPresenter
  Endpoint = Data.define(:method, :path, :description, :example)

  def initialize(book, base_url:)
    @book = book
    @base_url = base_url.to_s.chomp("/")
    @key = book.uid
  end

  def endpoints
    [
      Endpoint.new("GET", api_path("/api/v1/books/#{@key}"), "Метаданные книги", nil),
      Endpoint.new("GET", api_path("/api/v1/books/#{@key}/toc"), "Всё оглавление (дерево секций)", nil),
      Endpoint.new(
        "GET",
        api_path("/api/v1/books/#{@key}/sections/1"),
        "Текст секции оглавления по id",
        api_path("/api/v1/books/#{@key}/sections/1")
      ),
      Endpoint.new(
        "GET",
        api_path("/api/v1/books/#{@key}/toc/search"),
        "Поиск по заголовкам оглавления",
        "#{api_path("/api/v1/books/#{@key}/toc/search")}?q=глава"
      ),
      Endpoint.new(
        "GET",
        api_path("/api/v1/books/#{@key}/pages/1"),
        page_endpoint_description,
        api_path("/api/v1/books/#{@key}/pages/1")
      ),
      Endpoint.new(
        "GET",
        api_path("/api/v1/books/#{@key}/pages"),
        "Диапазон страниц (from, to)",
        "#{api_path("/api/v1/books/#{@key}/pages")}?from=1&to=3"
      ),
      Endpoint.new(
        "GET",
        api_path("/api/v1/books/#{@key}/search"),
        "Полнотекстовый поиск по книге (Elasticsearch)",
        "#{api_path("/api/v1/books/#{@key}/search")}?q=текст&context_chars=600"
      )
    ]
  end

  private

  def api_path(path)
    "#{@base_url}#{path}"
  end

  def page_endpoint_description
    if @book.physical_pages?
      "Текст страницы PDF (номер 1…#{@book.page_count})"
    else
      "Текст виртуальной страницы (номер 1…#{@book.page_count})"
    end
  end
end
