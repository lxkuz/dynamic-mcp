module Books
  module Import
    class TocDiscoveryAgent < ActiveHarness::Agent
      include DeepseekAgent

      system_prompt TocDiscoveryPrompt
      format :json
    end
  end
end
