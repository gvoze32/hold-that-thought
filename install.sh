#!/usr/bin/env bash
# Install /q for Claude Code (user level) as a symlink to this repo.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)/commands/q.md"
DST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/q.md"
mkdir -p "$(dirname "$DST")"
if [ -e "$DST" ] && [ ! -L "$DST" ]; then
  BAK="$DST.bak.$(date +%s)"
  mv "$DST" "$BAK"
  echo "Existing file backed up to $BAK"
fi
ln -sfn "$SRC" "$DST"
echo "✓ /q installed: $DST -> $SRC"
echo "  Start a new Claude Code session to pick it up."
