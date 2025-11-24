require "file_utils"
require "json"

struct Config
  include JSON::Serializable

  getter path : String = "~/scries"
  getter agent : String = "claude"
  getter instructions : String = "CLAUDE.md"

  def self.load : Config
    config_path = File.expand_path("~/.config/scry/config.json", home: Path.home)

    if File.exists?(config_path)
      begin
        return Config.from_json(File.read(config_path))
      rescue ex
        STDERR.puts "Warning: Could not parse config: #{ex.message}"
      end
    end

    Config.new
  end

  def initialize
    @path = ENV["SCRY_PATH"]? || "~/scries"
    @agent = ENV["SCRY_AGENT"]? || "claude"
    @instructions = ENV["SCRY_INSTRUCTIONS"]? || "CLAUDE.md"
  end

  def effective_path : String
    path = ENV["SCRY_PATH"]? || @path
    path.starts_with?("~") ? File.expand_path(path, home: Path.home) : path
  end

  def effective_agent : String
    ENV["SCRY_AGENT"]? || @agent
  end

  def effective_instructions : String
    ENV["SCRY_INSTRUCTIONS"]? || @instructions
  end
end

module RawMode
  @@original : LibC::Termios?
  @@raw_mode = false

  def self.enable
    return if @@raw_mode

    original = uninitialized LibC::Termios
    LibC.tcgetattr(STDIN.fd, pointerof(original))
    @@original = original

    raw = original
    raw.c_lflag &= ~(LibC::ICANON | LibC::ECHO)
    raw.c_cc[16] = 1_u8 # VMIN
    raw.c_cc[17] = 0_u8 # VTIME

    LibC.tcsetattr(STDIN.fd, LibC::TCSANOW, pointerof(raw))
    @@raw_mode = true
  end

  def self.disable
    return unless @@raw_mode
    if orig = @@original
      o = orig
      LibC.tcsetattr(STDIN.fd, LibC::TCSANOW, pointerof(o))
    end
    @@raw_mode = false
  end
end

module UI
  TOKENS = {
    "{text}"           => "\e[39m",
    "{dim_text}"       => "\e[90m",
    "{h1}"             => "\e[1;33m",
    "{h2}"             => "\e[1;36m",
    "{highlight}"      => "\e[1;33m",
    "{reset}"          => "\e[0m\e[39m\e[49m",
    "{reset_bg}"       => "\e[49m",
    "{reset_fg}"       => "\e[39m",
    "{clear_screen}"   => "\e[2J",
    "{clear_line}"     => "\e[2K",
    "{home}"           => "\e[H",
    "{clear_below}"    => "\e[0J",
    "{hide_cursor}"    => "\e[?25l",
    "{show_cursor}"    => "\e[?25h",
    "{start_selected}" => "\e[1m",
    "{end_selected}"   => "\e[0m",
    "{bold}"           => "\e[1m",
  }

  @@buffer = [] of String
  @@last_buffer = [] of String
  @@current_line = ""
  @@width : Int32? = nil
  @@height : Int32? = nil

  def self.print(text : String)
    @@current_line += text
  end

  def self.puts(text : String = "")
    @@current_line += text
    @@buffer << @@current_line
    @@current_line = ""
  end

  def self.flush(io = STDERR)
    unless @@current_line.empty?
      @@buffer << @@current_line
      @@current_line = ""
    end

    unless io.tty?
      plain = @@buffer.join("\n").gsub(/\{.*?\}/, "")
      io.print(plain)
      io.print("\n") unless plain.ends_with?("\n")
      @@last_buffer.clear
      @@buffer.clear
      io.flush
      return
    end

    io.print("\e[H")

    max_lines = {@@buffer.size, @@last_buffer.size}.max
    reset = TOKENS["{reset}"]

    (0...max_lines).each do |i|
      current_line = @@buffer[i]? || ""
      last_line = @@last_buffer[i]? || ""

      if current_line != last_line
        io.print("\e[#{i + 1};1H\e[2K")
        unless current_line.empty?
          io.print(expand_tokens(current_line))
          io.print(reset)
        end
      end
    end

    @@last_buffer = @@buffer.dup
    @@buffer.clear
    io.flush
  end

  def self.cls(io = STDERR)
    @@current_line = ""
    @@buffer.clear
    @@last_buffer.clear
    io.print("\e[2J\e[H")
  end

  def self.expand_tokens(str : String) : String
    str.gsub(/\{.*?\}/) { |match| TOKENS[match]? || match }
  end

  def self.width : Int32
    @@width ||= begin
      result = `tput cols 2>/dev/null`.strip.to_i?
      result && result > 0 ? result : 80
    end
  end

  def self.height : Int32
    @@height ||= begin
      result = `tput lines 2>/dev/null`.strip.to_i?
      result && result > 0 ? result : 24
    end
  end

  def self.refresh_size
    @@width = nil
    @@height = nil
  end

  def self.read_key : String
    buf = Bytes.new(1)
    STDIN.read(buf)
    input = String.new(buf)

    if input == "\e"
      STDIN.read_timeout = 0.05.seconds
      begin
        extra = Bytes.new(5)
        bytes_read = STDIN.read(extra)
        input += String.new(extra[0, bytes_read]) if bytes_read > 0
      rescue IO::TimeoutError
      ensure
        STDIN.read_timeout = nil
      end
    end

    input
  end
end

struct ScryDir
  getter name : String
  getter path : String
  getter ctime : Time
  getter mtime : Time
  property score : Float64

  def initialize(@name, @path, @ctime, @mtime)
    @score = 0.0
  end
end

module Scoring
  def self.fuzzy_match(text : String, query : String) : Float64
    return 0.0 if query.empty?

    text_lower = text.downcase
    query_lower = query.downcase
    query_chars = query_lower.chars
    query_len = query_chars.size
    text_len = text_lower.size

    score = 0.0
    last_pos = -1
    query_idx = 0
    i = 0

    while i < text_len
      break if query_idx >= query_len

      if text_lower[i] == query_chars[query_idx]
        score += 1.0

        is_boundary = (i == 0) || !text_lower[i - 1].alphanumeric?
        score += 1.0 if is_boundary

        if last_pos >= 0
          gap = i - last_pos - 1
          score += 1.0 / Math.sqrt(gap + 1)
        end

        last_pos = i
        query_idx += 1
      end

      i += 1
    end

    return 0.0 if query_idx < query_len

    if last_pos >= 0
      score *= (query_len.to_f / (last_pos + 1))
    end

    score *= (10.0 / (text.size + 10.0))
    score
  end

  def self.time_decay(age_seconds : Float64, weight : Float64 = 1.0) : Float64
    weight / Math.sqrt(age_seconds + 1)
  end

  def self.format_relative_time(seconds_ago : Float64) : String
    minutes = seconds_ago / 60
    hours = minutes / 60
    days = hours / 24

    if seconds_ago < 10
      "just now"
    elsif minutes < 60
      "#{minutes.to_i}m ago"
    elsif hours < 24
      "#{hours.to_i}h ago"
    elsif days < 30
      "#{days.to_i}d ago"
    elsif days < 365
      "#{(days / 30).to_i}mo ago"
    else
      "#{(days / 365).to_i}y ago"
    end
  end
end

class ScrySelector
  @search_term : String
  @cursor_pos : Int32 = 0
  @scroll_offset : Int32 = 0
  @input_buffer : String
  @selected : NamedTuple(type: Symbol, path: String)?
  @base_path : String
  @delete_status : String?
  @all_scries : Array(ScryDir)?

  def initialize(search_term = "", base_path : String = "")
    @search_term = search_term.gsub(/\s+/, "-")
    @input_buffer = @search_term
    @base_path = base_path.empty? ? File.expand_path("~/scries") : base_path
    @selected = nil

    FileUtils.mkdir_p(@base_path) unless Dir.exists?(@base_path)
  end

  def run : NamedTuple(type: Symbol, path: String)?
    setup_terminal

    Signal::WINCH.trap { UI.refresh_size }

    RawMode.enable
    main_loop
  ensure
    restore_terminal
    RawMode.disable
  end

  private def setup_terminal
    UI.cls
    STDERR.print("\e[2J\e[H\e[?25l")
  end

  private def restore_terminal
    STDERR.print("\e[2J\e[H\e[?25h")
  end

  private def load_all_scries : Array(ScryDir)
    @all_scries ||= begin
      scries = [] of ScryDir

      Dir.each_child(@base_path) do |entry|
        next if entry.starts_with?('.')

        path = File.join(@base_path, entry)
        next unless File.directory?(path)

        info = File.info(path)
        scries << ScryDir.new(
          name: entry,
          path: path,
          ctime: info.modification_time,
          mtime: info.modification_time
        )
      end

      scries
    end
  end

  private def get_scries : Array(ScryDir)
    all = load_all_scries

    scored = all.map do |scry|
      scry.score = calculate_score(scry, @input_buffer)
      scry
    end

    if @input_buffer.empty?
      scored.sort_by { |scry| -scry.score }
    else
      scored.select { |scry| scry.score > 0 }.sort_by! { |scry| -scry.score }
    end
  end

  private def calculate_score(scry : ScryDir, query : String) : Float64
    score = 0.0

    if scry.name.matches?(/^\d{4}-\d{2}-\d{2}-/)
      score += 2.0
    end

    score += Scoring.fuzzy_match(scry.name, query)

    now = Time.utc
    days_old = (now - scry.ctime).total_seconds / 86400
    score += Scoring.time_decay(days_old, 2.0)

    hours_since_access = (now - scry.mtime).total_seconds / 3600
    score += Scoring.time_decay(hours_since_access, 3.0)

    score
  end

  private def main_loop
    loop do
      scries = get_scries
      total_items = scries.size + 1

      @cursor_pos = @cursor_pos.clamp(0, total_items - 1)

      render(scries)

      key = UI.read_key

      case key
      when "\r"
        if @cursor_pos < scries.size
          handle_selection(scries[@cursor_pos])
        else
          handle_create_new
        end
        break if @selected
      when "\e[A", "\x10", "\x0B"
        @cursor_pos = {@cursor_pos - 1, 0}.max
      when "\e[B", "\x0E", "\n"
        @cursor_pos = {@cursor_pos + 1, total_items - 1}.min
      when "\e[C", "\e[D"
        # ignore left/right arrows
      when "\x7F", "\b"
        @input_buffer = @input_buffer[0...-1] if @input_buffer.size > 0
        @cursor_pos = 0
      when "\x04"
        if @cursor_pos < scries.size
          handle_delete(scries[@cursor_pos])
        end
      when "\x03", "\e"
        @selected = nil
        break
      else
        if key.size == 1 && key[0].alphanumeric? || key[0].in?('-', '_', '.', ' ')
          @input_buffer += key
          @cursor_pos = 0
        end
      end
    end

    @selected
  end

  private def render(scries : Array(ScryDir))
    term_width = UI.width
    term_height = UI.height

    separator = "\u2500" * (term_width - 1)

    UI.puts "{h1}Scry"
    UI.puts "{dim_text}#{separator}"

    UI.puts "{highlight}Search: {reset}#{@input_buffer}"
    UI.puts "{dim_text}#{separator}"

    max_visible = {term_height - 8, 3}.max
    total_items = scries.size + 1

    if @cursor_pos < @scroll_offset
      @scroll_offset = @cursor_pos
    elsif @cursor_pos >= @scroll_offset + max_visible
      @scroll_offset = @cursor_pos - max_visible + 1
    end

    visible_end = {@scroll_offset + max_visible, total_items}.min

    (@scroll_offset...visible_end).each do |idx|
      if idx == scries.size && !scries.empty? && idx >= @scroll_offset
        UI.puts
      end

      is_selected = idx == @cursor_pos
      UI.print(is_selected ? "{highlight}> {reset_fg}" : "  ")

      if idx < scries.size
        scry = scries[idx]

        UI.print "{start_selected}" if is_selected

        if match = scry.name.match(/^(\d{4}-\d{2}-\d{2})-(.+)$/)
          date_part = match[1]
          name_part = match[2]

          UI.print "{dim_text}#{date_part}{reset_fg}"

          separator_matches = !@input_buffer.empty? && @input_buffer.includes?('-')
          if separator_matches
            UI.print "{highlight}-{reset_fg}"
          else
            UI.print "{dim_text}-{reset_fg}"
          end

          if !@input_buffer.empty?
            UI.print highlight_matches(name_part, @input_buffer, is_selected)
          else
            UI.print name_part
          end

          display_text = "#{date_part}-#{name_part}"
        else
          if !@input_buffer.empty?
            UI.print highlight_matches(scry.name, @input_buffer, is_selected)
          else
            UI.print scry.name
          end
          display_text = scry.name
        end

        time_text = format_relative_time(scry.mtime)
        score_text = sprintf("%.1f", scry.score)
        meta_text = "#{time_text}, #{score_text}"

        meta_width = meta_text.size + 1
        text_width = display_text.size
        padding_needed = term_width - 5 - text_width - meta_width
        padding = " " * {padding_needed, 1}.max

        UI.print padding
        UI.print "{end_selected}" if is_selected
        UI.print " {dim_text}#{meta_text}{reset_fg}"
      else
        UI.print "+ "
        UI.print "{start_selected}" if is_selected

        display_text = @input_buffer.empty? ? "Create new" : "Create new: #{@input_buffer}"
        UI.print display_text

        text_width = display_text.size
        padding_needed = term_width - 5 - text_width
        UI.print " " * {padding_needed, 1}.max
      end

      UI.puts
    end

    if total_items > max_visible
      UI.puts "{dim_text}#{separator}"
      UI.puts "{dim_text}[#{@scroll_offset + 1}-#{visible_end}/#{total_items}]"
    end

    UI.puts "{dim_text}#{separator}"

    if status = @delete_status
      UI.puts "{highlight}#{status}{reset}"
      @delete_status = nil
    else
      UI.puts "{dim_text}Up/Down: Navigate  Enter: Select  Ctrl-D: Delete  ESC: Cancel{reset}"
    end

    UI.flush
  end

  private def format_relative_time(time : Time) : String
    Scoring.format_relative_time((Time.utc - time).total_seconds)
  end

  private def highlight_matches(text : String, query : String, is_selected : Bool) : String
    return text if query.empty?

    result = ""
    text_lower = text.downcase
    query_lower = query.downcase
    query_chars = query_lower.chars
    query_index = 0

    text.each_char_with_index do |char, i|
      if query_index < query_chars.size && text_lower[i] == query_chars[query_index]
        result += "{highlight}#{char}{text}"
        query_index += 1
      else
        result += char
      end
    end

    result
  end

  private def handle_selection(scry : ScryDir)
    @selected = {type: :cd, path: scry.path}
  end

  private def handle_create_new
    date_prefix = Time.local.to_s("%Y-%m-%d")

    if !@input_buffer.empty?
      final_name = "#{date_prefix}-#{@input_buffer}".gsub(/\s+/, "-")
      full_path = File.join(@base_path, final_name)
      @selected = {type: :mkdir, path: full_path}
    else
      RawMode.disable
      UI.cls
      STDERR.puts "Enter new scry name:"
      STDERR.print "> #{date_prefix}-"
      STDERR.print("\e[?25h")

      entry = STDIN.gets.try(&.chomp) || ""

      if entry.empty?
        @selected = nil
        return
      end

      final_name = "#{date_prefix}-#{entry}".gsub(/\s+/, "-")
      full_path = File.join(@base_path, final_name)
      @selected = {type: :mkdir, path: full_path}

      RawMode.enable
    end
  end

  private def handle_delete(scry : ScryDir)
    size = `du -sh #{scry.path} 2>/dev/null`.strip.split(/\s+/).first? || "???"
    files = `find #{scry.path} -type f 2>/dev/null | wc -l`.strip

    RawMode.disable
    UI.cls
    STDERR.puts "Delete Directory"
    STDERR.puts
    STDERR.puts "Are you sure you want to delete: #{scry.name}"
    STDERR.puts "  Path: #{scry.path}"
    STDERR.puts "  Files: #{files}"
    STDERR.puts "  Size: #{size}"
    STDERR.puts
    STDERR.print "Type YES to confirm: "
    STDERR.print("\e[?25h")

    confirmation = STDIN.gets.try(&.chomp) || ""

    if confirmation == "YES"
      begin
        if Dir.current == scry.path
          Dir.cd(@base_path)
        end
        FileUtils.rm_rf(scry.path)
        @delete_status = "Deleted: #{scry.name}"
        @all_scries = nil
      rescue ex
        @delete_status = "Error: #{ex.message}"
      end
    else
      @delete_status = "Delete cancelled"
    end

    STDERR.print("\e[?25l")
    RawMode.enable
  end
end

def generate_readme(name : String) : String
  <<-README
  # #{name}

  Temporary directory created by scry for AI-assisted development.
  README
end

def print_help(config : Config)
  help = <<-HELP
  Scry - temporary directories for AI coding agents

  Usage:
    scry [QUERY]              Browse/create scries and launch agent
    scry init                 Print shell function for ~/.zshrc

  Examples:
    scry                      Browse all scries
    scry redis                Jump to matching scry

  Keys:
    Up/Down     Navigate
    Enter       Select/Create
    Ctrl-D      Delete
    ESC         Cancel

  Current config:
    Path:         #{config.effective_path}
    Agent:        #{config.effective_agent}
    Instructions: #{config.effective_instructions}

  Environment (overrides config file):
    SCRY_PATH          Where scries are stored
    SCRY_AGENT         Command to run after cd (e.g., claude, codex, aider)
    SCRY_INSTRUCTIONS  Markdown file to create in new directories

  Config file: ~/.config/scry/config.json
    {
      "path": "~/scries",
      "agent": "claude",
      "instructions": "CLAUDE.md"
    }

  HELP
  puts help
end

def print_init_script
  script_path = Process.executable_path || "scry"

  puts <<-SHELL
  scry() {
    result=$("#{script_path}" cd "$@" 2>/dev/tty)
    rc=$?
    if [ $rc -eq 0 ] && [ -n "$result" ]; then
      eval "$result"
    fi
  }
  SHELL
end

{% unless flag?(:spec) %}
  config = Config.load

  if ARGV.includes?("--help") || ARGV.includes?("-h")
    print_help(config)
    exit 0
  end

  command = ARGV.shift?

  case command
  when nil
    print_help(config)
    exit 2
  when "init"
    print_init_script
    exit 0
  when "cd"
    search_term = ARGV.join(" ")
    selector = ScrySelector.new(search_term, base_path: config.effective_path)

    unless STDIN.tty? && STDERR.tty?
      STDERR.puts "Error: scry requires an interactive terminal"
      exit 1
    end

    result = selector.run

    if result
      path = result[:path]

      if result[:type] == :mkdir
        FileUtils.mkdir_p(path)
        instructions_path = File.join(path, config.effective_instructions)
        name = File.basename(path).sub(/^\d{4}-\d{2}-\d{2}-/, "")
        File.write(instructions_path, generate_readme(name))
      end

      File.touch(path)
      puts "cd '#{path}' && #{config.effective_agent}"
    end
  else
    STDERR.puts "Unknown command: #{command}"
    print_help(config)
    exit 2
  end
{% end %}
