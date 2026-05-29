module Api
  module V1
    module Books
      class TocController < Api::BaseController
        include BookScoped

        before_action :set_book

        def show
          roots = @book.sections.where(parent_id: nil).order(:position)
          render json: {
            uid: @book.uid,
            toc: roots.map(&:as_toc_node)
          }
        end

        def search
          results = Search::Query.toc(book_id: @book.id, query: params.require(:q))
          render json: { uid: @book.uid, query: params[:q], results: results }
        end
      end
    end
  end
end
