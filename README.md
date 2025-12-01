# Scry

Create and navigate date-prefixed directories for AI coding agents. Inspired by Toby Lütke's [try](https://github.com/tobi/try).

## Installation

Download the latest binary from [Releases](https://github.com/stephendolan/scry/releases):

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

**Navigation**: `↑`/`↓` to move, `Enter` to select, `Ctrl-D` to delete, `ESC` to exit, type to filter

## Configuration

Optional. Create `~/.config/scry/config.json` or use environment variables:

```json
{
  "path": "~/scries",
  "agent": "claude",
  "instructions": "CLAUDE.md"
}
```

```bash
export SCRY_AGENT=aider        # Use different AI agent
export SCRY_PATH=~/experiments # Custom storage location
```

## License

MIT
