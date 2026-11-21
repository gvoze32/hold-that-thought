#!/usr/bin/env bash
set -euo pipefail
DST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/q.md"
if [ -e "$DST" ] || [ -L "$DST" ]; then
  rm "$DST"
  echo "✓ /q removed ($DST)"
else
  echo "No /q at $DST; nothing removed."
fi
