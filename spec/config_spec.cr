require "./spec_helper"

describe Config do
  describe "#initialize" do
    it "has default values" do
      config = Config.new
      config.path.should eq("~/scries")
      config.agent.should eq("claude")
      config.instructions.should eq("CLAUDE.md")
    end
  end

  describe "#effective_path" do
    it "expands tilde in path" do
      config = Config.new
      config.effective_path.should start_with("/")
      config.effective_path.should end_with("/scries")
      config.effective_path.should_not contain("~")
    end
  end

  describe "#effective_agent" do
    it "returns default agent" do
      config = Config.new
      config.effective_agent.should eq("claude")
    end
  end

  describe "#effective_instructions" do
    it "returns default instructions file" do
      config = Config.new
      config.effective_instructions.should eq("CLAUDE.md")
    end
  end

  describe ".from_json" do
    it "parses custom config" do
      json = %({ "path": "/custom/path", "agent": "aider", "instructions": "README.md" })
      config = Config.from_json(json)
      config.path.should eq("/custom/path")
      config.agent.should eq("aider")
      config.instructions.should eq("README.md")
    end

    it "uses defaults for missing fields" do
      json = %({ "agent": "codex" })
      config = Config.from_json(json)
      config.path.should eq("~/scries")
      config.agent.should eq("codex")
      config.instructions.should eq("CLAUDE.md")
    end
  end
end
