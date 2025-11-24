require "./spec_helper"

describe UI do
  describe ".expand_tokens" do
    it "expands known tokens to ANSI codes" do
      result = UI.expand_tokens("{h1}Title{reset}")
      result.should contain("\e[1;33m")
      result.should contain("\e[0m")
    end

    it "leaves unknown tokens unchanged" do
      result = UI.expand_tokens("{unknown}")
      result.should eq("{unknown}")
    end
  end
end
