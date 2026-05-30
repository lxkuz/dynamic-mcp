class ImportBookJob
  include Sidekiq::Job

  sidekiq_options queue: :book_imports, retry: 0

  def perform(book_id)
    book = Book.find(book_id)
    Books::Import::Runner.call(book)
  end
end
