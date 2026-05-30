class UploadsController < ApplicationController
  def new
  end

  def create
    @book = Books::CreateFromUpload.call(params.require(:file))
    redirect_to upload_result_path(@book.uid)
  rescue ArgumentError, StandardError => e
    @error = e.message
    render :new, status: :unprocessable_entity
  end

  def show
    @book = Book.includes(book_import: :events).find_by!(uid: params[:uid])
    @book_import = @book.book_import
    @import_progress = Books::Import::Progress.payload_for(@book_import)

    if @book.ready?
      @endpoints = BookEndpointsPresenter.new(@book, base_url: request.base_url).endpoints
      @mcp_doc_url = Mcp::DocumentationUrl.for(@book)
    else
      @endpoints = []
      @mcp_doc_url = nil
    end
  end

  def status
    book = Book.includes(book_import: :events).find_by!(uid: params[:uid])
    import = book.book_import

    render json: {
      uid: book.uid,
      status: book.status,
      title: book.title,
      author: book.author,
      page_count: book.page_count,
      error_message: book.error_message,
      import: Books::Import::Progress.payload_for(import)
    }
  end
end
