module Api
  module V1
    module Books
      class SearchesController < Api::BaseController
        include BookScoped

        before_action :set_book

        def show
          results = Search::Query.fulltext(
            book_id: @book.id,
            query: params.require(:q),
            context_chars: params[:context_chars].to_i
          )
          render json: { uid: @book.uid, query: params[:q], results: results }
        end
      end
    end
  end
end
