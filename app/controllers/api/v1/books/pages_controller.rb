module Api
  module V1
    module Books
      class PagesController < Api::BaseController
        include BookScoped

        before_action :set_book

        def show
          page = @book.pages.find_by!(number: params[:page_number])
          render json: {
            uid: @book.uid,
            page_number: page.number,
            content: page.readable_text,
            total_pages: @book.page_count
          }
        end
      end
    end
  end
end
