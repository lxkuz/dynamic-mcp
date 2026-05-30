module Api
  module V1
    module Books
      class PagesController < Api::BaseController
        include BookScoped

        before_action :set_book

        def index
          payload = ::Books::PageRange.fetch(
            @book,
            from: params.require(:from).to_i,
            to: params.require(:to).to_i
          )
          render json: payload.merge(uid: @book.uid)
        rescue ArgumentError => e
          render json: { error: e.message }, status: :unprocessable_entity
        end

        def show
          page = @book.pages.find_by!(number: params[:page_number])
          render json: {
            uid: @book.uid,
            page_number: page.number,
            text: page.readable_text,
            total_pages: @book.page_count
          }
        end
      end
    end
  end
end
