module Books
  module Import
    module DeepseekAgent
      extend ActiveSupport::Concern

      included do
        model do
          use provider: :deepseek, model: "deepseek-chat", temperature: 0.2
          fallback provider: :deepseek, model: "deepseek-reasoner", temperature: 0.1
        end
      end
    end
  end
end
