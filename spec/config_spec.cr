require "./spec_helper"

describe Config do
  describe "#effective_path" do
    it "expands tilde in path" do
      config = Config.new
      config.effective_path.should start_with("/")
      config.effective_path.should_not contain("~")
    end
  end

  describe ".from_json" do
    it "parses custom config" do
      json = %({ "path": "/custom/path", "agent": "opencode" })
      config = Config.from_json(json)
      config.path.should eq("/custom/path")
      config.agent.should eq("opencode")
    end

    it "uses defaults for missing fields" do
      json = %({ "agent": "codex" })
      config = Config.from_json(json)
      config.path.should eq("~/scries")
      config.agent.should eq("codex")
    end
  end
end
