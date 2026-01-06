# Scry

Create and navigate date-prefixed directories for AI coding agents. Inspired by Toby Lütke's [try](https://github.com/tobi/try).

## Installation

Download the latest binary from [Releases](https://github.com/stephendolan/scry/releases):

```bash
# macOS (Apple Silicon)
curl -L https://github.com/stephendolan/scry/releases/latest/download/scry-macos-arm64.tar.gz | tar xz
sudo mv scry /usr/local/bin/

# Linux
curl -L https://github.com/stephendolan/scry/releases/latest/download/scry-linux-x86_64.tar.gz | tar xz
sudo mv scry /usr/local/bin/
```

Or build from source (requires [Crystal](https://crystal-lang.org/) 1.18+):

```bash
git clone https://github.com/stephendolan/scry.git
cd scry
shards build --release
sudo mv bin/scry /usr/local/bin/
```

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
eval "$(scry init)"
```

## Usage

```bash
scry                      # Browse existing directories
scry metrics              # Jump to matching directory or filter
scry order-daycare-lunch  # Create new directory if no match
```

**Navigation**:
- `↑`/`↓` or `Ctrl-K`/`Ctrl-J` or `Ctrl-P`/`Ctrl-N` - Move cursor
- `Enter` - Select directory or create new
- `Ctrl-D` - Delete selected directory
- `ESC`/`Ctrl-C` - Exit
- Type to filter (fuzzy matching)

## Templates

Bootstrap new scry directories with predefined files.

**Setup**: Create template directories in `~/.config/scry/templates/`:

```bash
mkdir -p ~/.config/scry/templates/default
echo "# Instructions for Claude" > ~/.config/scry/templates/default/CLAUDE.md
echo "*.log" > ~/.config/scry/templates/default/.gitignore
```

**Usage**:

```bash
scry templates                          # List available templates
scry "ACME audit"                       # Creates directory with default template
scry "security-review" --template audit # Apply audit template instead
```

The `default` template is applied automatically when creating new directories. All files from the template directory are copied to the new scry directory.

## Cleanup

Remove old directories by age or date:

```bash
scry cleanup 30              # Delete directories older than 30 days
scry cleanup 2024-01-01      # Delete directories before this date
scry cleanup                 # Interactive prompt
```

Shows preview with directory names, age, size, and file count before deletion.

## Configuration

Optional configuration via `~/.config/scry/config.json` or environment variables:

```json
{
  "path": "~/scries",
  "agent": "claude"
}
```

Environment variables override config file settings:

```bash
export SCRY_PATH=~/experiments  # Custom directory location
export SCRY_AGENT=opencode      # Different AI agent command
```

## License

MIT
