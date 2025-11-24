require "./spec_helper"

describe Scoring do
  describe ".fuzzy_match" do
    it "returns 0 when no match possible" do
      Scoring.fuzzy_match("hello", "").should eq(0.0)
      Scoring.fuzzy_match("hello", "xyz").should eq(0.0)
      Scoring.fuzzy_match("hi", "hello").should eq(0.0)
    end

    it "scores exact prefix match highly" do
      prefix_score = Scoring.fuzzy_match("redis-server", "red")
      middle_score = Scoring.fuzzy_match("a-redis-b", "red")
      prefix_score.should be > middle_score
    end

    it "scores word boundary matches higher" do
      boundary_score = Scoring.fuzzy_match("r-s", "rs")
      non_boundary_score = Scoring.fuzzy_match("rxs", "rs")
      boundary_score.should be > non_boundary_score
    end

    it "scores consecutive matches higher" do
      consecutive = Scoring.fuzzy_match("abc", "abc")
      spread = Scoring.fuzzy_match("axbxc", "abc")
      consecutive.should be > spread
    end

    it "prefers shorter strings for same match" do
      short = Scoring.fuzzy_match("api", "api")
      long = Scoring.fuzzy_match("api-server-test", "api")
      short.should be > long
    end

    it "is case insensitive" do
      lower = Scoring.fuzzy_match("Redis", "redis")
      upper = Scoring.fuzzy_match("REDIS", "redis")
      lower.should eq(upper)
    end

    it "matches typical scry patterns" do
      score = Scoring.fuzzy_match("2024-11-24-redis-experiment", "redis")
      score.should be > 0
    end
  end

  describe ".time_decay" do
    it "decreases with age" do
      recent = Scoring.time_decay(1.0)
      old = Scoring.time_decay(100.0)
      recent.should be > old
    end

    it "applies weight multiplier" do
      weighted = Scoring.time_decay(10.0, 3.0)
      unweighted = Scoring.time_decay(10.0, 1.0)
      weighted.should eq(unweighted * 3)
    end
  end

  describe ".format_relative_time" do
    it "formats time appropriately for each unit" do
      Scoring.format_relative_time(5.0).should eq("just now")
      Scoring.format_relative_time(120.0).should eq("2m ago")
      Scoring.format_relative_time(3600.0).should eq("1h ago")
      Scoring.format_relative_time(86400.0).should eq("1d ago")
      Scoring.format_relative_time(86400.0 * 45).should eq("1mo ago")
      Scoring.format_relative_time(86400.0 * 400).should eq("1y ago")
    end
  end
end
