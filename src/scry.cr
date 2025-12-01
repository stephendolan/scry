require "file_utils"
require "json"

VERSION = {{ `shards version`.stringify.chomp }}

struct Config
  include JSON::Serializable

  getter path : String = "~/scries"
  getter agent : String = "claude"
  getter instructions : String = "CLAUDE.md"

  def self.load : Config
    config_path = File.expand_path("~/.config/scry/config.json", home: Path.home)

    return Config.new unless File.exists?(config_path)

    begin
      Config.from_json(File.read(config_path))
    rescue ex
      STDERR.puts "Warning: Could not parse config: #{ex.message}"
      Config.new
    end
  end

  def initialize
    @path = "~/scries"
    @agent = "claude"
    @instructions = "CLAUDE.md"
  end

  def effective_path : String
    expand_home_path(ENV["SCRY_PATH"]? || @path)
  end

  def effective_agent : String
    ENV["SCRY_AGENT"]? || @agent
  end

  def effective_instructions : String
    ENV["SCRY_INSTRUCTIONS"]? || @instructions
  end

  private def expand_home_path(path : String) : String
    path.starts_with?("~") ? File.expand_path(path, home: Path.home) : path
  end
end

module RawMode
  VMIN  = 16
  VTIME = 17

  @@original : LibC::Termios?
  @@raw_mode = false

  def self.enable
    return if @@raw_mode || !STDIN.tty?

    original = fetch_current_termios
    return unless original

    @@original = original
    return unless apply_raw_mode(original)

    @@raw_mode = true
  end

  private def self.fetch_current_termios : LibC::Termios?
    original = uninitialized LibC::Termios
    result = LibC.tcgetattr(STDIN.fd, pointerof(original))
    result == 0 ? original : nil
  end

  private def self.apply_raw_mode(original : LibC::Termios) : Bool
    raw = original
    raw.c_lflag &= ~(LibC::ICANON | LibC::ECHO)
    raw.c_cc[VMIN] = 1_u8
    raw.c_cc[VTIME] = 0_u8

    LibC.tcsetattr(STDIN.fd, LibC::TCSANOW, pointerof(raw)) == 0
  end

  def self.disable
    return unless @@raw_mode
    restore_termios
    @@raw_mode = false
  end

  def self.force_restore
    restore_termios
    @@raw_mode = false
    STDERR.print("\e[?25h")
  end

  private def self.restore_termios
    return unless orig = @@original
    o = orig
    LibC.tcsetattr(STDIN.fd, LibC::TCSANOW, pointerof(o))
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
    complete_current_line

    if io.tty?
      flush_tty(io)
    else
      flush_non_tty(io)
    end
  end

  private def self.complete_current_line
    return if @@current_line.empty?
    @@buffer << @@current_line
    @@current_line = ""
  end

  private def self.flush_non_tty(io)
    plain = @@buffer.join("\n").gsub(/\{.*?\}/, "")
    io.print(plain)
    io.print("\n") unless plain.ends_with?("\n")
    @@last_buffer.clear
    @@buffer.clear
    io.flush
  end

  private def self.flush_tty(io)
    io.print("\e[H")

    max_lines = {@@buffer.size, @@last_buffer.size}.max

    (0...max_lines).each do |i|
      current_line = @@buffer[i]? || ""
      last_line = @@last_buffer[i]? || ""

      if current_line != last_line
        io.print("\e[#{i + 1};1H\e[2K")
        unless current_line.empty?
          io.print(expand_tokens(current_line))
          io.print(TOKENS["{reset}"])
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
    @@width ||= detect_terminal_dimension("cols", 80)
  end

  def self.height : Int32
    @@height ||= detect_terminal_dimension("lines", 24)
  end

  private def self.detect_terminal_dimension(dimension : String, default : Int32) : Int32
    result = `tput #{dimension} 2>/dev/null`.strip.to_i?
    result && result > 0 ? result : default
  end

  def self.refresh_size
    @@width = nil
    @@height = nil
    @@last_buffer.clear
  end

  def self.read_key : String
    input = read_first_byte

    if input == "\e"
      input += read_escape_sequence
    end

    input
  end

  private def self.read_first_byte : String
    buf = Bytes.new(1)
    STDIN.read(buf)
    String.new(buf)
  end

  private def self.read_escape_sequence : String
    current = uninitialized LibC::Termios
    return "" unless LibC.tcgetattr(STDIN.fd, pointerof(current)) == 0

    timed = current
    timed.c_cc[RawMode::VMIN] = 0_u8
    timed.c_cc[RawMode::VTIME] = 1_u8
    return "" unless LibC.tcsetattr(STDIN.fd, LibC::TCSANOW, pointerof(timed)) == 0

    extra = Bytes.new(5)
    bytes_read = LibC.read(STDIN.fd, extra.to_unsafe, extra.size)
    bytes_read = 0 if bytes_read < 0

    LibC.tcsetattr(STDIN.fd, LibC::TCSANOW, pointerof(current))

    bytes_read > 0 ? String.new(extra[0, bytes_read]) : ""
  end
end

module KeyboardInput
  abstract def read_key : String
end

class StandardKeyboard
  include KeyboardInput

  def read_key : String
    UI.read_key
  end
end

class MockKeyboard
  include KeyboardInput

  getter keys_read : Int32 = 0

  def initialize(@keys : Array(String))
  end

  def read_key : String
    key = @keys[@keys_read]? || "\e"
    @keys_read += 1
    key
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
    query_chars = query.downcase.chars

    last_pos, score = find_matches(text_lower, query_chars)
    return 0.0 if score == 0.0

    apply_scoring_modifiers(score, query_chars.size, last_pos, text.size)
  end

  private def self.find_matches(text : String, query_chars : Array(Char)) : {Int32, Float64}
    score = 0.0
    last_pos = -1
    query_idx = 0

    text.each_char_with_index do |char, i|
      break if query_idx >= query_chars.size

      if char == query_chars[query_idx]
        score += 1.0
        score += 1.0 if word_boundary?(text, i)
        score += proximity_bonus(last_pos, i)
        last_pos = i
        query_idx += 1
      end
    end

    {last_pos, query_idx == query_chars.size ? score : 0.0}
  end

  private def self.word_boundary?(text : String, position : Int32) : Bool
    position == 0 || !text[position - 1].alphanumeric?
  end

  private def self.proximity_bonus(last_pos : Int32, current_pos : Int32) : Float64
    return 0.0 if last_pos < 0
    gap = current_pos - last_pos - 1
    1.0 / Math.sqrt(gap + 1)
  end

  private def self.apply_scoring_modifiers(score : Float64, query_len : Int32, last_pos : Int32, text_len : Int32) : Float64
    score *= (query_len.to_f / (last_pos + 1)) if last_pos >= 0
    score *= (10.0 / (text_len + 10.0))
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
  @keyboard : KeyboardInput
  @output : IO
  @interactive : Bool

  def initialize(search_term = "", base_path : String = "", keyboard : KeyboardInput? = nil, output : IO? = nil, interactive : Bool = true)
    @search_term = search_term.gsub(/\s+/, "-")
    @input_buffer = @search_term
    @base_path = base_path.empty? ? File.expand_path("~/scries") : base_path
    @selected = nil
    @keyboard = keyboard || StandardKeyboard.new
    @output = output || STDERR
    @interactive = interactive

    FileUtils.mkdir_p(@base_path) unless Dir.exists?(@base_path)
  end

  getter cursor_pos : Int32
  getter input_buffer : String

  def run : NamedTuple(type: Symbol, path: String)?
    setup_terminal

    if @interactive
      enable_blocking_io
      RawMode.enable
      Signal::WINCH.trap { UI.refresh_size }
      Signal::INT.trap { RawMode.force_restore; exit(130) }
      Signal::TERM.trap { RawMode.force_restore; exit(143) }
    end

    main_loop
  ensure
    if @interactive
      restore_terminal
      RawMode.disable
    end
  end

  private def enable_blocking_io
    # Crystal 1.16+ on macOS throws "kevent: Invalid argument" when the event loop
    # tries to register STDIN/STDERR in raw mode. Using blocking I/O bypasses the event loop.
    {% if compare_versions(Crystal::VERSION, "1.18.0") >= 0 %}
      IO::FileDescriptor.set_blocking(STDIN.fd, true)
      IO::FileDescriptor.set_blocking(STDERR.fd, true)
    {% else %}
      STDIN.blocking = true
      STDERR.blocking = true
    {% end %}
  end

  private def setup_terminal
    return unless @interactive
    UI.cls
    @output.print("\e[2J\e[H\e[?25l")
  end

  private def restore_terminal
    return unless @interactive
    @output.print("\e[2J\e[H\e[?25h")
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

    if @input_buffer.empty?
      score_all_scries(all)
    else
      filter_and_score_scries(all)
    end
  end

  private def score_all_scries(scries : Array(ScryDir)) : Array(ScryDir)
    scries.each { |scry| scry.score = calculate_score(scry, "") }
    scries.sort_by { |scry| -scry.score }
  end

  private def filter_and_score_scries(scries : Array(ScryDir)) : Array(ScryDir)
    matched = scries.compact_map do |scry|
      fuzzy_score = Scoring.fuzzy_match(scry.name, @input_buffer)
      if fuzzy_score > 0
        scry.score = calculate_score(scry, @input_buffer, fuzzy_score)
        scry
      end
    end
    matched.sort_by! { |scry| -scry.score }
  end

  private def calculate_score(scry : ScryDir, query : String, fuzzy_score : Float64 = 0.0) : Float64
    score = 0.0
    score += 2.0 if scry.name.matches?(/^\d{4}-\d{2}-\d{2}-/)
    score += fuzzy_score > 0 ? fuzzy_score : Scoring.fuzzy_match(scry.name, query)
    score += recency_score(scry)
    score
  end

  private def recency_score(scry : ScryDir) : Float64
    now = Time.utc
    days_old = (now - scry.ctime).total_seconds / 86400
    hours_since_access = (now - scry.mtime).total_seconds / 3600

    Scoring.time_decay(days_old, 2.0) + Scoring.time_decay(hours_since_access, 3.0)
  end

  private def main_loop
    loop do
      scries = get_scries
      total_items = scries.size + 1

      @cursor_pos = @cursor_pos.clamp(0, total_items - 1)

      render(scries)

      key = @keyboard.read_key
      handle_key(key, scries, total_items)

      break if @selected || key.in?("\x03", "\e")
    end

    @selected
  end

  private def handle_key(key : String, scries : Array(ScryDir), total_items : Int32)
    case key
    when "\r", "\n"
      handle_enter(scries)
    when "\e[A", "\x10", "\x0B"
      move_cursor_up
    when "\e[B", "\x0E"
      move_cursor_down(total_items)
    when "\e[C", "\e[D"
      # ignore left/right arrows
    when "\x7F", "\b"
      handle_backspace
    when "\x04"
      handle_delete_key(scries)
    when "\x03", "\e"
      @selected = nil
    else
      handle_character_input(key)
    end
  end

  private def handle_enter(scries : Array(ScryDir))
    if @cursor_pos < scries.size
      handle_selection(scries[@cursor_pos])
    else
      handle_create_new
    end
  end

  private def move_cursor_up
    @cursor_pos = {@cursor_pos - 1, 0}.max
  end

  private def move_cursor_down(total_items : Int32)
    @cursor_pos = {@cursor_pos + 1, total_items - 1}.min
  end

  private def handle_backspace
    return if @input_buffer.empty?
    @input_buffer = @input_buffer[0...-1]
    @cursor_pos = 0
  end

  private def handle_delete_key(scries : Array(ScryDir))
    handle_delete(scries[@cursor_pos]) if @cursor_pos < scries.size
  end

  private def handle_character_input(key : String)
    if key.size == 1 && (key[0].alphanumeric? || key[0].in?('-', '_', '.', ' '))
      @input_buffer += key
      @cursor_pos = 0
    end
  end

  private def render(scries : Array(ScryDir))
    term_width = UI.width
    term_height = UI.height
    separator = "\u2500" * (term_width - 1)

    render_header(separator)
    render_items(scries, term_width, term_height, separator)
    render_footer(separator)

    UI.flush(@output)
  end

  private def render_header(separator : String)
    UI.puts "{h1}Scry"
    UI.puts "{dim_text}#{separator}"
    UI.puts "{highlight}Search: {reset}#{@input_buffer}"
    UI.puts "{dim_text}#{separator}"
  end

  private def render_items(scries : Array(ScryDir), term_width : Int32, term_height : Int32, separator : String)
    max_visible = {term_height - 8, 3}.max
    total_items = scries.size + 1

    update_scroll_offset(max_visible)
    visible_end = {@scroll_offset + max_visible, total_items}.min

    (@scroll_offset...visible_end).each do |idx|
      UI.puts if idx == scries.size && !scries.empty? && idx >= @scroll_offset

      is_selected = idx == @cursor_pos
      render_item(scries, idx, is_selected, term_width)
      UI.puts
    end

    render_scroll_indicator(total_items, max_visible, visible_end, separator)
  end

  private def update_scroll_offset(max_visible : Int32)
    if @cursor_pos < @scroll_offset
      @scroll_offset = @cursor_pos
    elsif @cursor_pos >= @scroll_offset + max_visible
      @scroll_offset = @cursor_pos - max_visible + 1
    end
  end

  private def render_scroll_indicator(total_items : Int32, max_visible : Int32, visible_end : Int32, separator : String)
    return if total_items <= max_visible
    UI.puts "{dim_text}#{separator}"
    UI.puts "{dim_text}[#{@scroll_offset + 1}-#{visible_end}/#{total_items}]"
  end

  private def render_item(scries : Array(ScryDir), idx : Int32, is_selected : Bool, term_width : Int32)
    UI.print(is_selected ? "{highlight}> {reset_fg}" : "  ")

    if idx < scries.size
      render_scry_item(scries[idx], is_selected, term_width)
    else
      render_create_new_item(is_selected, term_width)
    end
  end

  private def render_scry_item(scry : ScryDir, is_selected : Bool, term_width : Int32)
    UI.print "{start_selected}" if is_selected

    display_text = render_scry_name(scry)

    time_text = Scoring.format_relative_time((Time.utc - scry.mtime).total_seconds)
    score_text = sprintf("%.1f", scry.score)
    meta_text = "#{time_text}, #{score_text}"

    padding = calculate_padding(display_text, meta_text, term_width)

    UI.print padding
    UI.print "{end_selected}" if is_selected
    UI.print " {dim_text}#{meta_text}{reset_fg}"
  end

  private def render_scry_name(scry : ScryDir) : String
    if match = scry.name.match(/^(\d{4}-\d{2}-\d{2})-(.+)$/)
      render_date_prefixed_name(match[1], match[2])
    else
      render_plain_name(scry.name)
    end
  end

  private def render_date_prefixed_name(date_part : String, name_part : String) : String
    UI.print "{dim_text}#{date_part}{reset_fg}"

    separator_matches = !@input_buffer.empty? && @input_buffer.includes?('-')
    UI.print separator_matches ? "{highlight}-{reset_fg}" : "{dim_text}-{reset_fg}"

    if @input_buffer.empty?
      UI.print name_part
    else
      UI.print highlight_matches(name_part, @input_buffer, false)
    end

    "#{date_part}-#{name_part}"
  end

  private def render_plain_name(name : String) : String
    if @input_buffer.empty?
      UI.print name
    else
      UI.print highlight_matches(name, @input_buffer, false)
    end
    name
  end

  private def render_create_new_item(is_selected : Bool, term_width : Int32)
    UI.print "+ "
    UI.print "{start_selected}" if is_selected

    display_text = @input_buffer.empty? ? "Create new" : "Create new: #{@input_buffer}"
    UI.print display_text

    padding = " " * {term_width - 5 - display_text.size, 1}.max
    UI.print padding
  end

  private def calculate_padding(display_text : String, meta_text : String, term_width : Int32) : String
    padding_needed = term_width - 5 - display_text.size - meta_text.size - 1
    " " * {padding_needed, 1}.max
  end

  private def render_footer(separator : String)
    UI.puts "{dim_text}#{separator}"

    if status = @delete_status
      UI.puts "{highlight}#{status}{reset}"
      @delete_status = nil
    else
      UI.puts "{dim_text}Up/Down: Navigate  Enter: Select  Ctrl-D: Delete  ESC: Cancel{reset}"
    end
  end

  private def highlight_matches(text : String, query : String, is_selected : Bool) : String
    return text if query.empty?

    result = ""
    query_chars = query.downcase.chars
    query_index = 0

    text.each_char_with_index do |char, i|
      if matches_query?(text, i, query_chars, query_index)
        result += "{highlight}#{char}{text}"
        query_index += 1
      else
        result += char
      end
    end

    result
  end

  private def matches_query?(text : String, position : Int32, query_chars : Array(Char), query_index : Int32) : Bool
    query_index < query_chars.size && text.downcase[position] == query_chars[query_index]
  end

  private def handle_selection(scry : ScryDir)
    @selected = {type: :cd, path: scry.path}
  end

  private def handle_create_new
    if @input_buffer.empty?
      prompt_for_name
    else
      date_prefix = Time.local.to_s("%Y-%m-%d")
      final_name = "#{date_prefix}-#{@input_buffer}".gsub(/\s+/, "-")
      full_path = File.join(@base_path, final_name)
      @selected = {type: :mkdir, path: full_path}
    end
  end

  private def prompt_for_name
    date_prefix = Time.local.to_s("%Y-%m-%d")

    RawMode.disable
    UI.cls
    STDERR.puts "Enter new scry name:"
    STDERR.print "> #{date_prefix}-"
    STDERR.print("\e[?25h")

    entry = STDIN.gets.try(&.chomp) || ""
    return @selected = nil if entry.empty?

    final_name = "#{date_prefix}-#{entry}".gsub(/\s+/, "-")
    full_path = File.join(@base_path, final_name)
    @selected = {type: :mkdir, path: full_path}
  ensure
    RawMode.enable
  end

  private def handle_delete(scry : ScryDir)
    size = get_directory_size(scry.path)
    files = count_files(scry.path)

    RawMode.disable
    UI.cls

    display_delete_prompt(scry, files, size)
    confirmation = STDIN.gets.try(&.chomp) || ""

    if confirmation == "YES"
      delete_directory(scry)
    else
      @delete_status = "Delete cancelled"
    end
  ensure
    STDERR.print("\e[?25l")
    RawMode.enable
  end

  private def get_directory_size(path : String) : String
    output = IO::Memory.new
    Process.run("du", ["-sh", path], output: output, error: Process::Redirect::Close)
    output.to_s.strip.split(/\s+/).first? || "???"
  rescue
    "???"
  end

  private def count_files(path : String) : String
    output = IO::Memory.new
    Process.run("find", [path, "-type", "f"], output: output, error: Process::Redirect::Close)
    output.to_s.lines.size.to_s
  rescue
    "???"
  end

  private def display_delete_prompt(scry : ScryDir, files : String, size : String)
    STDERR.puts "Delete Directory"
    STDERR.puts
    STDERR.puts "Are you sure you want to delete: #{scry.name}"
    STDERR.puts "  Path: #{scry.path}"
    STDERR.puts "  Files: #{files}"
    STDERR.puts "  Size: #{size}"
    STDERR.puts
    STDERR.print "Type YES to confirm: "
    STDERR.print("\e[?25h")
  end

  private def delete_directory(scry : ScryDir)
    Dir.cd(@base_path) if Dir.current == scry.path
    FileUtils.rm_rf(scry.path)
    @delete_status = "Deleted: #{scry.name}"
    @all_scries = nil
  rescue ex
    @delete_status = "Error: #{ex.message}"
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
    scry cleanup [DAYS|DATE]  Delete old directories

  Examples:
    scry                      Browse all scries
    scry redis                Jump to matching scry
    scry cleanup 30           Delete dirs older than 30 days
    scry cleanup 2024-01-01   Delete dirs before that date

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

def parse_cleanup_arg(arg : String?) : Time?
  return nil unless arg

  if days = arg.to_i?
    return nil if days <= 0
    Time.utc - days.days
  elsif arg.matches?(/^\d{4}-\d{2}-\d{2}$/)
    Time.parse(arg, "%Y-%m-%d", Time::Location::UTC)
  else
    nil
  end
rescue
  nil
end

def prompt_for_cutoff : Time?
  STDERR.print "Delete directories older than (days or YYYY-MM-DD): "
  input = STDIN.gets.try(&.chomp)
  return nil if !input || input.empty?
  parse_cleanup_arg(input)
end

def find_old_directories(base_path : String, cutoff : Time) : Array(String)
  old_dirs = [] of String

  Dir.each_child(base_path) do |entry|
    next if entry.starts_with?('.')
    path = File.join(base_path, entry)
    next unless File.directory?(path)

    info = File.info(path)
    last_activity = {info.modification_time, File.info(path, follow_symlinks: false).modification_time}.max
    old_dirs << path if last_activity < cutoff
  end

  old_dirs.sort_by { |dir| File.info(dir).modification_time }
end

def calculate_total_size(dirs : Array(String)) : String
  return "0B" if dirs.empty?

  output = IO::Memory.new
  Process.run("du", ["-sh"] + dirs, output: output, error: Process::Redirect::Close)
  lines = output.to_s.lines
  return "???" if lines.empty?

  target_line = lines.size == 1 ? lines.first : lines.last
  target_line.split(/\s+/).first? || "???"
rescue
  "???"
end

def display_cleanup_preview(dirs : Array(String), cutoff : Time, total_size : String)
  STDERR.puts "Found #{dirs.size} director#{dirs.size == 1 ? "y" : "ies"} older than #{cutoff.to_s("%Y-%m-%d")}:"
  STDERR.puts

  dirs.each do |path|
    name = File.basename(path)
    info = File.info(path)
    age = Scoring.format_relative_time((Time.utc - info.modification_time).total_seconds)
    STDERR.puts "  #{name}  (#{age})"
  end

  STDERR.puts
  STDERR.puts "Total size: #{total_size}"
  STDERR.puts
end

def delete_directories(dirs : Array(String))
  deleted = 0
  errors = 0

  dirs.each do |path|
    begin
      FileUtils.rm_rf(path)
      deleted += 1
    rescue
      errors += 1
    end
  end

  STDERR.puts "Deleted #{deleted} director#{deleted == 1 ? "y" : "ies"}"
  STDERR.puts "#{errors} error(s) occurred" if errors > 0
end

def run_cleanup(config : Config, arg : String?)
  base_path = config.effective_path

  unless Dir.exists?(base_path)
    STDERR.puts "Scry directory does not exist: #{base_path}"
    return
  end

  cutoff = parse_cleanup_arg(arg)
  if cutoff.nil? && arg
    STDERR.puts "Invalid input: #{arg}"
    STDERR.puts "Use a number of days (e.g., 30) or a date (e.g., 2024-01-01)"
    return
  end

  cutoff ||= prompt_for_cutoff
  if cutoff.nil?
    STDERR.puts "Invalid input. Use a number of days (e.g., 30) or a date (e.g., 2024-01-01)"
    return
  end

  old_dirs = find_old_directories(base_path, cutoff)

  if old_dirs.empty?
    STDERR.puts "No directories found older than #{cutoff.to_s("%Y-%m-%d")}"
    return
  end

  total_size = calculate_total_size(old_dirs)
  display_cleanup_preview(old_dirs, cutoff, total_size)

  STDERR.print "Type YES to delete: "
  confirmation = STDIN.gets.try(&.chomp)

  if confirmation == "YES"
    delete_directories(old_dirs)
  else
    STDERR.puts "Cleanup cancelled"
  end
end

{% unless flag?(:spec) %}
  config = Config.load

  if ARGV.includes?("--version") || ARGV.includes?("-v")
    puts VERSION
    exit 0
  end

  if ARGV.includes?("--help") || ARGV.includes?("-h")
    print_help(config)
    exit 0
  end

  if ARGV.first? == "init"
    print_init_script
    exit 0
  end

  # Strip "cd" prefix added by shell function wrapper
  ARGV.shift if ARGV.first? == "cd"

  if ARGV.first? == "cleanup"
    ARGV.shift
    run_cleanup(config, ARGV.first?)
    exit 0
  end

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

    escaped_path = path.gsub("'", "'\\''")
    puts "cd '#{escaped_path}' && #{config.effective_agent}"
    File.touch(path) rescue nil
  end
{% end %}
