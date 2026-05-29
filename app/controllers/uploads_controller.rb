class UploadsController < ApplicationController
  def new
  end

  def create
    @book = Books::CreateFromUpload.call(params.require(:file))
    @endpoints = BookEndpointsPresenter.new(@book, base_url: request.base_url).endpoints
    @mcp_doc_url = Mcp::DocumentationUrl.for(@book)
    render :show
  rescue ArgumentError, StandardError => e
    @error = e.message
    render :new, status: :unprocessable_entity
  end
end
