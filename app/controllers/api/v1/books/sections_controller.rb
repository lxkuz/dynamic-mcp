module Api
  module V1
    module Books
      class SectionsController < Api::BaseController
        include BookScoped

        before_action :set_book

        def show
          section = @book.sections.find(params[:id])
          render json: {
            uid: @book.uid,
            section: {
              id: section.id,
              title: section.title,
              path: section.path,
              depth: section.depth,
              page_start: section.page_start,
              page_end: section.page_end,
              text: section.plain_text
            }
          }
        end
      end
    end
  end
end
