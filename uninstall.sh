#!/usr/bin/env bash
set -euo pipefail
DST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/q.md"
if [ -L "$DST" ]; then
  rm "$DST"
  echo "✓ /q removed ($DST)"
else
  echo "No /q symlink at $DST; nothing removed."
fi
