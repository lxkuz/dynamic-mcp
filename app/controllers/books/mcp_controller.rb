module Books
  class McpController < ApplicationController
    def show
      @book = Book.find_by!(uid: params[:uid])
      @doc = Mcp::DocumentationPresenter.new(@book, base_url: request.base_url)
      @api_endpoints = BookEndpointsPresenter.new(@book, base_url: request.base_url).endpoints
    end
  end
end
