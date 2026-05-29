module Api
  module V1
    module BookScoped
      extend ActiveSupport::Concern

      private

      def set_book
        @book = Book.find_by!(uid: book_uid_param)
        return if @book.ready?

        render json: { error: "Book is not ready", status: @book.status }, status: :conflict
      end

      def book_uid_param
        params[:uid] || params[:book_uid]
      end
    end
  end
end
