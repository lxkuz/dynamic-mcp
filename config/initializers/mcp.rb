# Loaded before mcp_middleware.rb — parent module must exist with constants
# before nested files (middleware, presenters) open `module Mcp`.
module Mcp
  SERVER_NAME = "dm".freeze
end
