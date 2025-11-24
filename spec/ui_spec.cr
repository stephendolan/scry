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

    it "expands multiple tokens" do
      result = UI.expand_tokens("{dim_text}dim{text}normal")
      result.should contain("\e[90m")
      result.should contain("\e[39m")
    end

    it "handles text without tokens" do
      result = UI.expand_tokens("plain text")
      result.should eq("plain text")
    end
  end
end
