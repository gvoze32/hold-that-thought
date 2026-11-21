#!/usr/bin/env bash
# hold-that-thought: install, update, check or remove the /q command for Claude Code.
#
#   curl -fsSL https://raw.githubusercontent.com/gvoze32/hold-that-thought/main/install.sh | bash                    # install / update
#   curl -fsSL https://raw.githubusercontent.com/gvoze32/hold-that-thought/main/install.sh | bash -s -- --check       # check for updates
#   curl -fsSL https://raw.githubusercontent.com/gvoze32/hold-that-thought/main/install.sh | bash -s -- --uninstall   # remove
#
# From a clone, ./install.sh symlinks the repo copy instead (edits apply live; update with git pull).
set -euo pipefail

RAW="https://raw.githubusercontent.com/gvoze32/hold-that-thought/main/commands/q.md"
DST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/q.md"
MODE="${1:-install}"

die() { echo "✗ $*" >&2; exit 1; }

fetch_latest() {
  LATEST="$(mktemp)"
  trap 'rm -f "$LATEST"' EXIT
  curl -fsSL "$RAW" -o "$LATEST" || die "Could not download $RAW"
}

repo_copy() {
  # Path to commands/q.md next to this script when run from a clone; empty when piped.
  local src="${BASH_SOURCE[0]:-}"
  if [ -n "$src" ] && [ -f "$src" ]; then
    local c
    c="$(cd "$(dirname "$src")" && pwd)/commands/q.md"
    [ -f "$c" ] && echo "$c"
  fi
  return 0
}

case "$MODE" in
  --check|check)
    [ -e "$DST" ] || { echo "/q is not installed ($DST)."; exit 2; }
    fetch_latest
    if [ -L "$DST" ]; then
      echo "/q is linked to a clone: $DST -> $(readlink "$DST")"
    fi
    if cmp -s "$LATEST" "$DST"; then
      echo "✓ /q is up to date."
      exit 0
    fi
    echo "↑ An update is available."
    if [ -L "$DST" ]; then
      echo "  Run 'git pull' in that clone."
    else
      echo "  Update: curl -fsSL https://raw.githubusercontent.com/gvoze32/hold-that-thought/main/install.sh | bash"
    fi
    exit 1
    ;;

  --uninstall|uninstall)
    if [ -e "$DST" ] || [ -L "$DST" ]; then
      rm "$DST"
      echo "✓ /q removed ($DST)"
    else
      echo "/q is not installed ($DST); nothing removed."
    fi
    ;;

  install|--install|update|--update)
    mkdir -p "$(dirname "$DST")"
    SRC="$(repo_copy)"
    if [ -n "$SRC" ]; then
      [ -e "$DST" ] && [ ! -L "$DST" ] && mv "$DST" "$DST.bak.$(date +%s)" && echo "Existing file backed up to $DST.bak.*"
      ln -sfn "$SRC" "$DST"
      echo "✓ /q linked: $DST -> $SRC"
    else
      fetch_latest
      if [ -e "$DST" ] && cmp -s "$LATEST" "$DST"; then
        echo "✓ /q is already up to date ($DST)"
        exit 0
      fi
      ACTION="installed"
      if [ -L "$DST" ]; then
        rm "$DST"
      elif [ -e "$DST" ]; then
        if head -n 5 "$DST" | grep -q "^description: Queue a message"; then
          ACTION="updated"
        else
          BAK="$DST.bak.$(date +%s)"
          mv "$DST" "$BAK"
          echo "A different q.md was there; backed up to $BAK"
        fi
      fi
      install -m 644 "$LATEST" "$DST"
      echo "✓ /q $ACTION: $DST"
    fi
    echo "  Start a new Claude Code session to pick it up."
    ;;

  -h|--help|help)
    sed -n '2,9p' "${BASH_SOURCE[0]:-/dev/null}" 2>/dev/null | sed 's/^# \{0,1\}//' || true
    echo "Modes: (none)=install/update, --check, --uninstall"
    ;;

  *)
    die "Unknown option: $MODE (use --check, --uninstall or no option)"
    ;;
esac
