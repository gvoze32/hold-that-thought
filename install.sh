#!/usr/bin/env bash
# Install /q for Claude Code (user level).
#   From a clone:  ./install.sh            -> symlink to the repo copy (edits apply live)
#   Without clone: curl -fsSL https://raw.githubusercontent.com/gvoze32/hold-that-thought/main/install.sh | bash
set -euo pipefail
RAW="https://raw.githubusercontent.com/gvoze32/hold-that-thought/main/commands/q.md"
DST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/q.md"
mkdir -p "$(dirname "$DST")"

SRC=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  CANDIDATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/commands/q.md"
  [ -f "$CANDIDATE" ] && SRC="$CANDIDATE"
fi

if [ -e "$DST" ] && [ ! -L "$DST" ] && ! curl -fsSL "$RAW" 2>/dev/null | cmp -s - "$DST"; then
  BAK="$DST.bak.$(date +%s)"
  mv "$DST" "$BAK"
  echo "Existing file backed up to $BAK"
fi

if [ -n "$SRC" ]; then
  ln -sfn "$SRC" "$DST"
  echo "✓ /q installed: $DST -> $SRC"
else
  TMP="$(mktemp)"
  curl -fsSL "$RAW" -o "$TMP"
  rm -f "$DST"
  mv "$TMP" "$DST"
  chmod 644 "$DST"
  echo "✓ /q installed: $DST"
fi
echo "  Start a new Claude Code session to pick it up."
