# Scry

Temporary directories for AI coding agents.

Quickly create and navigate date-prefixed directories for AI-assisted development sessions.

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

## Usage

```bash
scry                    # Browse all scries, launch agent
scry redis              # Jump to matching scry
scry api-experiment     # Create new scry if no match
```

### Keyboard shortcuts

| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate |
| `Enter` | Select or create |
| `Ctrl-D` | Delete |
| `ESC` | Cancel |
| Type | Filter |

## Configuration

Scry defaults to Claude but supports any AI coding agent.

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

Override config with environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `SCRY_PATH` | Directory for scries | `~/scries` |
| `SCRY_AGENT` | Command to run | `claude` |
| `SCRY_INSTRUCTIONS` | Markdown file to create | `CLAUDE.md` |

### Examples

```bash
# Use with Aider
export SCRY_AGENT=aider

# Use with Codex
export SCRY_AGENT=codex

# Custom path
export SCRY_PATH=~/experiments
```

## How it works

1. Creates directories like `2024-11-24-redis-experiment`
2. Fuzzy search with smart scoring (recency, word boundaries)
3. `cd` into directory and launch your AI agent
4. Seeds new directories with an instructions file

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
