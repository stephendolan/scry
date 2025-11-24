# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
shards install              # Install dependencies
crystal spec -Dspec         # Run all tests
crystal spec -Dspec spec/scoring_spec.cr  # Run single test file
./bin/ameba                 # Run linter
crystal tool format --check # Check formatting
crystal tool format         # Auto-format code
shards build --release --no-debug  # Build release binary
```

## Architecture

Single-file Crystal CLI (`src/scry.cr`) with these key components:

- **Config**: JSON-serializable struct loading from `~/.config/scry/config.json` with env var overrides (`SCRY_PATH`, `SCRY_AGENT`, `SCRY_INSTRUCTIONS`)
- **RawMode**: Terminal raw mode handling via LibC termios for keyboard input
- **UI**: Buffered rendering system with ANSI token expansion (`{h1}`, `{highlight}`, etc.) and diff-based screen updates
- **Scoring**: Fuzzy matching algorithm with word boundary bonuses, proximity scoring, and time decay for recency
- **ScrySelector**: Main interactive TUI - directory listing, filtering, creation, deletion

## Shell Integration

The CLI outputs shell commands to stdout (e.g., `cd '/path' && claude`) which the shell function from `scry init` evaluates. The TUI renders to stderr to keep stdout clean for command output.

## Test Flag

Tests use `-Dspec` flag which wraps the main execution block in `{% unless flag?(:spec) %}` to prevent running during tests.
