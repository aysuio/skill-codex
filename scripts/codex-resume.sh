#!/bin/sh

set -eu

CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
SESSIONS_DIR="$CODEX_HOME_DIR/sessions"
INDEX_FILE="$CODEX_HOME_DIR/session_index.jsonl"
LIMIT="${CODEX_RESUME_LIMIT:-20}"

usage() {
  cat <<'EOF'
Usage:
  codex-resume            # interactive picker (fzf if available, otherwise menu)
  codex-resume --list     # print recent sessions only
  codex-resume --last     # resume the most recent session
  codex-resume 3          # resume item 3 from the printed list
  codex-resume <session>  # resume by full id or unique id prefix

Environment:
  CODEX_HOME             Override Codex state directory (default: ~/.codex)
  CODEX_RESUME_LIMIT     Number of sessions to show (default: 20)
EOF
}

die() {
  printf '%s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

session_title() {
  id="$1"
  file="$2"
  title=""

  if [ -f "$INDEX_FILE" ]; then
    title=$(
      grep -F "\"id\":\"$id\"" "$INDEX_FILE" 2>/dev/null |
        tail -n 1 |
        sed -n 's/.*"thread_name":"\([^"]*\)".*/\1/p'
    )
  fi

  if [ -z "$title" ]; then
    title=$(head -n 1 "$file" | sed -n 's/.*"cwd":"\([^"]*\)".*/cwd=\1/p')
  fi

  if [ -z "$title" ]; then
    title="(no title)"
  fi

  printf '%s' "$title"
}

build_index() {
  out="$1"

  [ -d "$SESSIONS_DIR" ] || die "Sessions directory not found: $SESSIONS_DIR"

  : >"$out"
  n=0

  find "$SESSIONS_DIR" -type f -name 'rollout-*.jsonl' 2>/dev/null |
    sort -r |
    head -n "$LIMIT" |
    while IFS= read -r file; do
      n=$((n + 1))
      base=$(basename "$file" .jsonl)
      id=$(printf '%s' "$base" | sed -E 's/^.*-([0-9a-f-]{36})$/\1/')
      stamp=$(printf '%s' "$base" | sed -E 's/^rollout-([0-9]{4}-[0-9]{2}-[0-9]{2})T([0-9]{2})-([0-9]{2})-([0-9]{2})-[0-9a-f-]{36}$/\1 \2:\3:\4/')
      title=$(session_title "$id" "$file")
      printf '%s\t%s\t%s\t%s\t%s\n' "$n" "$id" "$stamp" "$title" "$file" >>"$out"
    done

  [ -s "$out" ] || die "No persisted sessions found under $SESSIONS_DIR"
}

print_index() {
  idx_file="$1"
  printf '%-4s %-19s %-36s %s\n' "No." "Time" "Session ID" "Title"
  while IFS='	' read -r idx sid stamp title _file; do
    printf '%-4s %-19s %-36s %s\n' "$idx" "$stamp" "$sid" "$title"
  done <"$idx_file"
}

interactive_pick() {
  idx_file="$1"

  if command -v fzf >/dev/null 2>&1; then
    selection=$(
      awk -F '	' '{ printf "%-4s %-19s %-36s %s\n", $1, $3, $2, $4 }' "$idx_file" |
        fzf --prompt='codex session> ' --header='Type to filter, Enter to resume, Ctrl-C to cancel'
    )
    [ -n "$selection" ] || exit 0
    printf '%s\n' "$selection" | awk '{ print $1 }'
    return 0
  fi

  print_index "$idx_file"
  while :; do
    printf '\nSelect session number or id (blank to cancel): '
    IFS= read -r choice
    [ -n "$choice" ] || exit 0
    if resolve_choice "$idx_file" "$choice" >/dev/null 2>&1; then
      printf '%s\n' "$choice"
      return 0
    fi
    printf 'Invalid selection: %s\n' "$choice" >&2
  done
}

resolve_choice() {
  idx_file="$1"
  query="$2"

  if [ "$query" = "--last" ]; then
    head -n 1 "$idx_file" | cut -f2
    return 0
  fi

  if printf '%s' "$query" | grep -Eq '^[0-9]+$'; then
    sid=$(awk -F '	' -v q="$query" '$1 == q { print $2; exit }' "$idx_file")
    [ -n "$sid" ] || die "List item not found: $query"
    printf '%s\n' "$sid"
    return 0
  fi

  matches=$(awk -F '	' -v q="$query" '$2 == q || index($2, q) == 1 { print $2 }' "$idx_file")
  count=$(printf '%s\n' "$matches" | sed '/^$/d' | wc -l | tr -d ' ')

  if [ "$count" -eq 1 ]; then
    printf '%s\n' "$matches" | sed -n '1p'
    return 0
  fi

  if [ "$count" -gt 1 ]; then
    die "Ambiguous session id prefix: $query"
  fi

  die "Session not found: $query"
}

main() {
  require_cmd codex
  require_cmd basename
  require_cmd find
  require_cmd awk
  require_cmd cut
  require_cmd grep
  require_cmd head
  require_cmd mktemp
  require_cmd sed
  require_cmd sort
  require_cmd tail
  require_cmd tr
  require_cmd wc

  idx_file=$(mktemp)
  trap 'rm -f "$idx_file"' EXIT INT TERM
  build_index "$idx_file"

  arg="${1:-}"

  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
    -l|--list)
      print_index "$idx_file"
      exit 0
      ;;
    "")
      arg=$(interactive_pick "$idx_file")
      ;;
  esac

  sid=$(resolve_choice "$idx_file" "$arg")
  exec codex resume "$sid"
}

main "$@"
