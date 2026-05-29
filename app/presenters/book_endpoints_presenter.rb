class BookEndpointsPresenter
  Endpoint = Data.define(:method, :path, :description, :example)

  def initialize(book, base_url:)
    @book = book
    @base_url = base_url.to_s.chomp("/")
    @uid = book.uid
  end

  def endpoints
    [
      Endpoint.new("GET", api_path("/api/v1/books/#{@uid}"), "Метаданные книги", nil),
      Endpoint.new("GET", api_path("/api/v1/books/#{@uid}/toc"), "Всё оглавление (дерево секций)", nil),
      Endpoint.new(
        "GET",
        api_path("/api/v1/books/#{@uid}/toc/search"),
        "Поиск по заголовкам оглавления",
        "#{api_path("/api/v1/books/#{@uid}/toc/search")}?q=глава"
      ),
      Endpoint.new(
        "GET",
        api_path("/api/v1/books/#{@uid}/pages/1"),
        page_endpoint_description,
        api_path("/api/v1/books/#{@uid}/pages/1")
      ),
      Endpoint.new(
        "GET",
        api_path("/api/v1/books/#{@uid}/search"),
        "Полнотекстовый поиск по книге (Elasticsearch)",
        "#{api_path("/api/v1/books/#{@uid}/search")}?q=текст"
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
