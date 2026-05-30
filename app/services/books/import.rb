module Books
  module Import
    MAX_ITERATIONS = 10
    SCRIPT_TIMEOUT_SECONDS = 600
    TOC_INSPECT_ROUNDS = 3
    PARSER_SANDBOX_IMAGE = ENV.fetch("PARSER_SANDBOX_IMAGE", "dynamic-mcp-parser-sandbox:latest")

    module_function

    def ai_enabled?
      flag = ActiveModel::Type::Boolean.new.cast(ENV.fetch("AI_IMPORT_ENABLED", "true"))
      flag && ENV["DEEPSEEK_API_KEY"].present?
    end
  end
end
