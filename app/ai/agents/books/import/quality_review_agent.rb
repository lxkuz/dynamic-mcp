module Books
  module Import
    class QualityReviewAgent < ActiveHarness::Agent
      include DeepseekAgent

      system_prompt QualityReviewPrompt
      format :json
    end
  end
end
