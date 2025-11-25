# Scry

Create and navigate date-prefixed directories for AI coding agents.

Inspired by Toby Lütke's [try](https://github.com/tobi/try).

## Installation

### From releases

Download the latest binary for your platform from [Releases](https://github.com/stephendolan/scry/releases).

```bash
# macOS (Apple Silicon)
curl -L https://github.com/stephendolan/scry/releases/latest/download/scry-macos-arm64.tar.gz | tar xz
sudo mv scry /usr/local/bin/

# macOS (Intel)
curl -L https://github.com/stephendolan/scry/releases/latest/download/scry-macos-x86_64.tar.gz | tar xz
sudo mv scry /usr/local/bin/

# Linux
curl -L https://github.com/stephendolan/scry/releases/latest/download/scry-linux-x86_64.tar.gz | tar xz
sudo mv scry /usr/local/bin/
```

### From source

Requires [Crystal](https://crystal-lang.org/) 1.18+.

```bash
git clone https://github.com/stephendolan/scry.git
cd scry
shards build --release
sudo mv bin/scry /usr/local/bin/
```

## Setup

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
eval "$(scry init)"
```

This creates a shell function that wraps the binary. The CLI outputs shell commands (e.g., `cd '/path' && claude`) which the shell function evaluates in your current session.

## Usage

```bash
scry                      # Browse and select from existing scries
scry metrics              # Jump to matching scry or filter list
scry order-daycare-lunch  # Create new scry if no match exists
```

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate list |
| `Enter` | Select directory or create new |
| `Ctrl-D` | Delete selected directory |
| `ESC` | Exit without selecting |
| Type | Filter results |

## Configuration

Defaults to Claude but supports any AI coding agent.

### Config file

Create `~/.config/scry/config.json`:

```json
{
  "path": "~/scries",
  "agent": "claude",
  "instructions": "CLAUDE.md"
}
```

### Environment variables

Environment variables override config file settings:

| Variable | Description | Default |
|----------|-------------|---------|
| `SCRY_PATH` | Storage directory | `~/scries` |
| `SCRY_AGENT` | Command to launch | `claude` |
| `SCRY_INSTRUCTIONS` | Instructions file to create | `CLAUDE.md` |

### Examples

```bash
export SCRY_AGENT=aider           # Use with Aider
export SCRY_AGENT=codex           # Use with Codex
export SCRY_PATH=~/experiments    # Custom storage path
```

## How it works

1. Creates date-prefixed directories: `2024-11-24-order-daycare-lunch`
2. Fuzzy search with smart scoring (recency, word boundaries, proximity)
3. Changes to selected directory and launches your AI agent
4. Seeds new directories with instructions file

## Development

```bash
# Install dependencies
shards install

# Run tests
crystal spec -Dspec

# Run linter
./bin/ameba

# Check formatting
crystal tool format --check

# Build release binary
shards build --release --no-debug
```

## License

MIT
