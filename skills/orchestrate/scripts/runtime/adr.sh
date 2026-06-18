#!/usr/bin/env bash
# adr.sh — judgment-memory helper: sequential ADR numbering + INDEX maintenance.
# Operates on ./docs/adr/ (tracked; ADR-0003/0005). Pure coreutils/sed/awk, no deps.
# The rationale prose is authored by the Planner/operator; this only mechanizes
# numbering, the INDEX row, and supersede status so capture can't race or drift.
#
#   adr.sh next                      # print the next zero-padded 4-digit number
#   adr.sh add <slug> <title>        # create docs/adr/NNNN-<slug>.md + active INDEX row; print the path
#   adr.sh supersede <NNNN> <byNNNN> # flip the NNNN row's status to "superseded by <byNNNN>"
set -euo pipefail
ADRDIR="docs/adr"; INDEX="$ADRDIR/INDEX.md"

ensure_index() {
  [ -f "$INDEX" ] && return 0
  mkdir -p "$ADRDIR"
  { echo "# Decision Index"; echo
    echo "One line per decision; the Planner reads this at intake and does not"
    echo "re-litigate an active decision. A goal contradicting an active record"
    echo "raises a DECISION_FORK citing it (supersede flow)."; echo
    echo "| ADR | Decision | Status |"
    echo "|-----|----------|--------|"
  } > "$INDEX"
}

next_num() {
  local last
  last="$(ls "$ADRDIR" 2>/dev/null | grep -oE '^[0-9]{4}' | sort -n | tail -1 || true)"
  printf '%04d\n' "$(( 10#${last:-0} + 1 ))"
}

cmd="${1:-}"; shift || true
case "$cmd" in
  next) next_num ;;

  add)
    slug="${1:?slug}"; title="${2:?title}"
    mkdir -p "$ADRDIR"; ensure_index
    num="$(next_num)"; f="$ADRDIR/$num-$slug.md"
    { printf '# %s\n\n' "$title"
      printf '<!-- captured from a DECISION_FORK resolution; fill in context + why -->\n\n'
      printf '_Status: active_\n'
    } > "$f"
    printf '| [%s](%s-%s.md) | %s | active |\n' "$num" "$num" "$slug" "$title" >> "$INDEX"
    printf '%s\n' "$f" ;;

  supersede)
    num="${1:?num}"; by="${2:?by}"
    [ -f "$INDEX" ] || { echo "no INDEX at $INDEX" >&2; exit 2; }
    sed -i -E "/\| \[$num\]/ s/\| active \|/| superseded by $by |/" "$INDEX" ;;

  *) echo "usage: adr.sh {next|add <slug> <title>|supersede <NNNN> <byNNNN>}" >&2; exit 64 ;;
esac
