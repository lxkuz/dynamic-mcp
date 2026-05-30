module Books
  module Import
    class ScriptFixAgent < ActiveHarness::Agent
      include DeepseekAgent

      system_prompt ScriptFixPrompt
    end
  end
end
