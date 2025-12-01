# CLAUDE.md

## Commands

```bash
shards install              # Install dependencies
crystal spec -Dspec         # Run tests
./bin/ameba                 # Lint
crystal tool format --check # Check formatting
shards build --release --no-debug  # Build binary
```

## Architecture

Single-file Crystal CLI (`src/scry.cr`, ~1000 lines):

| Module | Purpose |
|--------|---------|
| Config | JSON config from `~/.config/scry/config.json`, env var overrides |
| RawMode | Terminal raw mode via LibC termios |
| UI | Buffered ANSI rendering with diff-based updates |
| Scoring | Fuzzy matching with word boundaries, proximity, recency decay |
| ScrySelector | Interactive TUI for directory selection |

## Key Patterns

**Shell integration**: CLI outputs shell commands to stdout (`cd '/path' && claude`). TUI renders to stderr. The shell function from `scry init` evaluates stdout.

**Test isolation**: Tests use `-Dspec` flag. Main block wrapped in `{% unless flag?(:spec) %}`.

## Workflow

Submit changes via pull request to enable CI checks and auto-generated release notes.

Bump version in `shard.yml` to trigger automatic tagging and release.
