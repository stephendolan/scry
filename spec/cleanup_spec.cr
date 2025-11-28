require "./spec_helper"

describe "parse_cleanup_arg" do
  it "parses positive days" do
    result = parse_cleanup_arg("30")
    result.should_not be_nil
    result.not_nil!.should be_close(Time.utc - 30.days, 1.second)
  end

  it "parses single day" do
    result = parse_cleanup_arg("1")
    result.should_not be_nil
    result.not_nil!.should be_close(Time.utc - 1.day, 1.second)
  end

  it "parses YYYY-MM-DD dates" do
    result = parse_cleanup_arg("2024-01-15")
    result.should_not be_nil
    result.not_nil!.to_s("%Y-%m-%d").should eq("2024-01-15")
  end

  it "returns nil for invalid input" do
    parse_cleanup_arg("abc").should be_nil
    parse_cleanup_arg("not-a-date").should be_nil
  end

  it "returns nil for negative days" do
    parse_cleanup_arg("-5").should be_nil
    parse_cleanup_arg("0").should be_nil
  end

  it "returns nil for empty string" do
    parse_cleanup_arg("").should be_nil
  end

  it "returns nil for nil" do
    parse_cleanup_arg(nil).should be_nil
  end

  it "returns nil for malformed dates" do
    parse_cleanup_arg("2024-1-1").should be_nil
    parse_cleanup_arg("24-01-15").should be_nil
    parse_cleanup_arg("2024/01/15").should be_nil
  end
end

describe "find_old_directories" do
  it "finds directories older than cutoff" do
    test_dir = File.tempname("scry-cleanup-test")
    FileUtils.mkdir_p(test_dir)

    old_dir = File.join(test_dir, "2024-01-01-old-project")
    FileUtils.mkdir_p(old_dir)

    cutoff = Time.utc + 1.day
    result = find_old_directories(test_dir, cutoff)
    result.should contain(old_dir)

    FileUtils.rm_rf(test_dir)
  end

  it "excludes directories newer than cutoff" do
    test_dir = File.tempname("scry-cleanup-test")
    FileUtils.mkdir_p(test_dir)

    new_dir = File.join(test_dir, "2024-01-01-new-project")
    FileUtils.mkdir_p(new_dir)

    cutoff = Time.utc - 1.day
    result = find_old_directories(test_dir, cutoff)
    result.should be_empty

    FileUtils.rm_rf(test_dir)
  end

  it "excludes hidden directories" do
    test_dir = File.tempname("scry-cleanup-test")
    FileUtils.mkdir_p(test_dir)

    hidden_dir = File.join(test_dir, ".hidden")
    FileUtils.mkdir_p(hidden_dir)

    cutoff = Time.utc + 1.day
    result = find_old_directories(test_dir, cutoff)
    result.should_not contain(hidden_dir)

    FileUtils.rm_rf(test_dir)
  end

  it "returns empty array for empty directory" do
    test_dir = File.tempname("scry-cleanup-test")
    FileUtils.mkdir_p(test_dir)

    cutoff = Time.utc
    result = find_old_directories(test_dir, cutoff)
    result.should be_empty

    FileUtils.rm_rf(test_dir)
  end

  it "sorts by modification time" do
    test_dir = File.tempname("scry-cleanup-test")
    FileUtils.mkdir_p(test_dir)

    dir_a = File.join(test_dir, "aaa")
    dir_b = File.join(test_dir, "bbb")
    FileUtils.mkdir_p(dir_a)
    sleep 10.milliseconds
    FileUtils.mkdir_p(dir_b)

    cutoff = Time.utc + 1.day
    result = find_old_directories(test_dir, cutoff)
    result.should eq([dir_a, dir_b])

    FileUtils.rm_rf(test_dir)
  end
end

describe "calculate_total_size" do
  it "returns size for directories" do
    test_dir = File.tempname("scry-cleanup-test")
    FileUtils.mkdir_p(test_dir)

    result = calculate_total_size([test_dir])
    result.should_not eq("???")

    FileUtils.rm_rf(test_dir)
  end

  it "returns 0B for empty array" do
    result = calculate_total_size([] of String)
    result.should eq("0B")
  end
end
