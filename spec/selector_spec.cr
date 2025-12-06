require "./spec_helper"

describe ScrySelector do
  around_each do |example|
    test_dir = File.tempname("scry-test")
    FileUtils.mkdir_p(test_dir)

    begin
      example.run
    ensure
      FileUtils.rm_rf(test_dir)
    end
  end

  describe "navigation" do
    it "starts with cursor at position 0" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.cursor_pos.should eq(0)

      FileUtils.rm_rf(test_dir)
    end

    it "moves cursor down with down arrow" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-project-one"))
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-02-project-two"))

      keyboard = MockKeyboard.new(["\e[B", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.cursor_pos.should eq(1)

      FileUtils.rm_rf(test_dir)
    end

    it "moves cursor up with up arrow" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-project-one"))
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-02-project-two"))

      keyboard = MockKeyboard.new(["\e[B", "\e[B", "\e[A", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.cursor_pos.should eq(1)

      FileUtils.rm_rf(test_dir)
    end

    it "does not go below 0 when pressing up at top" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-project-one"))

      keyboard = MockKeyboard.new(["\e[A", "\e[A", "\e[A", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.cursor_pos.should eq(0)

      FileUtils.rm_rf(test_dir)
    end

    it "does not go past last item when pressing down at bottom" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-project-one"))

      keyboard = MockKeyboard.new(["\e[B", "\e[B", "\e[B", "\e[B", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.cursor_pos.should eq(1)

      FileUtils.rm_rf(test_dir)
    end

    it "supports Ctrl-P for up navigation" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-project-one"))
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-02-project-two"))

      keyboard = MockKeyboard.new(["\e[B", "\x10", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.cursor_pos.should eq(0)

      FileUtils.rm_rf(test_dir)
    end

    it "supports Ctrl-N for down navigation" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-project-one"))
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-02-project-two"))

      keyboard = MockKeyboard.new(["\x0E", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.cursor_pos.should eq(1)

      FileUtils.rm_rf(test_dir)
    end
  end

  describe "selection" do
    it "selects existing scry with enter" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      project_path = File.join(test_dir, "2024-01-01-my-project")
      FileUtils.mkdir_p(project_path)

      keyboard = MockKeyboard.new(["\r"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      result = selector.run
      result.should_not be_nil
      if r = result
        r[:type].should eq(:cd)
        r[:path].should eq(project_path)
      end

      FileUtils.rm_rf(test_dir)
    end

    it "returns nil when cancelled with ESC" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-my-project"))

      keyboard = MockKeyboard.new(["\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      result = selector.run
      result.should be_nil

      FileUtils.rm_rf(test_dir)
    end

    it "returns nil when cancelled with Ctrl-C" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-my-project"))

      keyboard = MockKeyboard.new(["\x03"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      result = selector.run
      result.should be_nil

      FileUtils.rm_rf(test_dir)
    end
  end

  describe "filtering" do
    it "filters scries by typed characters" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-alpha"))
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-02-beta"))
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-03-gamma"))

      keyboard = MockKeyboard.new(["b", "e", "t", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.input_buffer.should eq("bet")

      FileUtils.rm_rf(test_dir)
    end

    it "resets cursor to 0 when typing" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-alpha"))
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-02-beta"))

      keyboard = MockKeyboard.new(["\e[B", "a", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.cursor_pos.should eq(0)

      FileUtils.rm_rf(test_dir)
    end

    it "handles backspace to delete characters" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["t", "e", "s", "t", "\x7F", "\x7F", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.input_buffer.should eq("te")

      FileUtils.rm_rf(test_dir)
    end

    it "initializes with search term from constructor" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("initial", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.input_buffer.should eq("initial")

      FileUtils.rm_rf(test_dir)
    end

    it "converts spaces to hyphens in search term" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("my project", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.input_buffer.should eq("my-project")

      FileUtils.rm_rf(test_dir)
    end

    it "sanitizes filesystem-unsafe characters in search term" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("calendar -> Slack", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.input_buffer.should eq("calendar-Slack")

      FileUtils.rm_rf(test_dir)
    end

    it "collapses multiple dashes from unsafe characters" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("foo < > bar", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.input_buffer.should eq("foo-bar")

      FileUtils.rm_rf(test_dir)
    end

    it "strips leading and trailing dashes" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["\e"])
      output = IO::Memory.new
      selector = ScrySelector.new(">test<", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.input_buffer.should eq("test")

      FileUtils.rm_rf(test_dir)
    end
  end

  describe "creation" do
    it "selects create new option when cursor on last item" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["t", "e", "s", "t", "\r"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      result = selector.run
      result.should_not be_nil
      if r = result
        r[:type].should eq(:mkdir)
        r[:path].should contain("test")
      end

      FileUtils.rm_rf(test_dir)
    end

    it "includes date prefix in new scry path" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["n", "e", "w", "\r"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      result = selector.run
      result.should_not be_nil
      if r = result
        today = Time.local.to_s("%Y-%m-%d")
        r[:path].should contain(today)
      end

      FileUtils.rm_rf(test_dir)
    end
  end

  describe "rendering" do
    it "renders output to provided IO" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-test-project"))

      keyboard = MockKeyboard.new(["\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      rendered = output.to_s
      rendered.should contain("Scry")
      rendered.should contain("test-project")

      FileUtils.rm_rf(test_dir)
    end

    it "shows search prompt with current input" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["f", "o", "o", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      rendered = output.to_s
      rendered.should contain("Search:")
      rendered.should contain("foo")

      FileUtils.rm_rf(test_dir)
    end

    it "shows help text in footer" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      rendered = output.to_s
      rendered.should contain("Navigate")
      rendered.should contain("Enter")
      rendered.should contain("ESC")

      FileUtils.rm_rf(test_dir)
    end
  end

  describe "edge cases" do
    it "handles empty directory" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)

      keyboard = MockKeyboard.new(["\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      result = selector.run
      result.should be_nil
      selector.cursor_pos.should eq(0)

      FileUtils.rm_rf(test_dir)
    end

    it "ignores hidden directories" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, ".hidden"))
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-visible"))

      keyboard = MockKeyboard.new(["\e[B", "\e[B", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.cursor_pos.should eq(1)

      FileUtils.rm_rf(test_dir)
    end

    it "ignores left and right arrow keys" do
      test_dir = File.tempname("scry-test")
      FileUtils.mkdir_p(test_dir)
      FileUtils.mkdir_p(File.join(test_dir, "2024-01-01-test"))

      keyboard = MockKeyboard.new(["\e[C", "\e[D", "\e"])
      output = IO::Memory.new
      selector = ScrySelector.new("", base_path: test_dir, keyboard: keyboard, output: output, interactive: false)

      selector.run
      selector.cursor_pos.should eq(0)

      FileUtils.rm_rf(test_dir)
    end
  end
end
