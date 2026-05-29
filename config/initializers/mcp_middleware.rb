require Rails.root.join("app/middleware/mcp/book_middleware")

Rails.application.config.middleware.use Mcp::BookMiddleware
