module Books
  module Import
    class ParserScriptAuthorAgent < ActiveHarness::Agent
      include DeepseekAgent

      system_prompt ParserScriptPrompt
    end
  end
end
