module Books
  module Import
    class StructureAnalysisAgent < ActiveHarness::Agent
      include DeepseekAgent

      system_prompt StructureAnalysisPrompt
      format :json
    end
  end
end
