#!/usr/bin/env bash
# worktree.sh — mechanizes SKILL §9a/§9b worktree creation so the router does NOT rely
# on the harness's isolation:worktree (which cuts from a stale local base and can land
# on the main checkout). Pure git + coreutils (no yq/jq at runtime). The router passes
# ticket/persona/base_ref; the branch + path conventions match references/agents.yaml's
# `worktree:` block (branch_template / path / base_ref).
#
#   worktree.sh create <ticket> <persona> [base_ref]   # fetch + worktree from origin/<base>; reuse if current; safe-recreate if stale&clean; HALT if stale&has-work
#   worktree.sh staleness <ticket> <persona> [base_ref]# exit 0 current, 3 behind, 4 missing
#   worktree.sh remove <ticket> <persona>              # remove iff clean (never discards work)
#   worktree.sh path|branch <ticket> <persona>         # print the deterministic path/branch
#
# SAFETY: this helper NEVER destroys a worktree that holds work (uncommitted changes OR
# commits ahead of the base). On stale-with-work it exits 3 for operator/reground
# reconcile — the lesson from the reset --hard data-loss (ADR-0013).
set -uo pipefail

cmd="${1:-}"; shift || true
t="${1:-}"; p="${2:-}"; base="${3:-}"
# Base resolution (ADR-0013): explicit arg > the CURRENT checked-out branch > main.
# NEVER the repo default branch / origin/HEAD — that's the stale-orphan trap (a repo
# whose canonical branch is e.g. "blank-slate" has origin/HEAD pointing at a stale
# "master", and cutting worktrees from it pins every lane hundreds of commits behind).
if [ -z "$base" ]; then
  base="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  { [ -n "$base" ] && [ "$base" != HEAD ]; } || base="main"
fi
case "$cmd" in path|branch|create|staleness|remove) ;; *) echo "usage: worktree.sh {create|staleness|remove|path|branch} <ticket> <persona> [base_ref]" >&2; exit 64 ;; esac
[ -n "$t" ] && [ -n "$p" ] || { echo "worktree.sh: ticket and persona required" >&2; exit 64; }

BRANCH="worktree-agent-${t}-${p}"           # §9b naming (agents.yaml branch_template)
WT=".agents/worktrees/${t}-${p}"            # agents.yaml worktree.path

case "$cmd" in
  path)   printf '%s\n' "$WT"; exit 0 ;;
  branch) printf '%s\n' "$BRANCH"; exit 0 ;;
esac

# Does a registered worktree exist at WT? (absolute-path compare)
wt_abs="$(cd "$(dirname "$WT")" 2>/dev/null && pwd -P)/$(basename "$WT")" 2>/dev/null || wt_abs="$WT"
has_wt(){ git worktree list --porcelain 2>/dev/null | awk -v w="$wt_abs" '/^worktree /{if($2==w) f=1} END{exit f?0:1}'; }
# Work present in the worktree = uncommitted changes OR commits ahead of the fetched base.
has_work(){
  [ -d "$WT" ] || return 1
  [ -n "$(git -C "$WT" status --porcelain 2>/dev/null)" ] && return 0
  local ahead; ahead="$(git -C "$WT" rev-list --count "origin/$base..HEAD" 2>/dev/null || echo 0)"
  [ "${ahead:-0}" != 0 ]
}
# Behind = origin/<base> has advanced past what the worktree was cut from.
is_behind(){ [ -d "$WT" ] && ! git -C "$WT" merge-base --is-ancestor "origin/$base" HEAD 2>/dev/null; }

fetch(){ git rev-parse --verify "origin/$base" >/dev/null 2>&1 || true; git fetch origin --prune >/dev/null 2>&1 || true; }

case "$cmd" in
  staleness)
    fetch
    has_wt || { echo "missing: $WT" >&2; exit 4; }
    if is_behind; then echo "behind: $WT is stale vs origin/$base" >&2; exit 3; else exit 0; fi ;;

  remove)
    has_wt || exit 0
    if has_work; then echo "worktree.sh: refusing to remove $WT — it holds work (reconcile first)" >&2; exit 3; fi
    git worktree remove --force "$WT" >/dev/null 2>&1 || true
    git branch -D "$BRANCH" >/dev/null 2>&1 || true
    exit 0 ;;

  create)
    git rev-parse --git-dir >/dev/null 2>&1 || { echo "worktree.sh: not in a git repo" >&2; exit 1; }
    fetch
    git rev-parse --verify "origin/$base" >/dev/null 2>&1 || { echo "worktree.sh: origin/$base not found (fetch failed or wrong base_ref)" >&2; exit 1; }
    # Align origin/HEAD -> origin/<base>, so the harness's isolation:worktree (if it is
    # ever used instead of this helper) ALSO cuts from the right base rather than a stale
    # default-branch orphan. Local ref update only; reversible.
    git remote set-head origin "$base" >/dev/null 2>&1 || true
    if has_wt; then
      if is_behind; then
        if has_work; then echo "worktree.sh: $WT is STALE and holds work — HALT for reconcile (do not auto-recreate)" >&2; exit 3; fi
        git worktree remove --force "$WT" >/dev/null 2>&1 || true
        git branch -D "$BRANCH" >/dev/null 2>&1 || true
      else
        printf '%s\n' "$WT"; exit 0   # exists and current -> reuse
      fi
    fi
    mkdir -p "$(dirname "$WT")"
    # Orphan branch (worktree gone, branch left): -B resets it from the fresh base.
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
      git worktree add -B "$BRANCH" "$WT" "origin/$base" >/dev/null 2>&1 || { echo "worktree.sh: worktree add -B failed" >&2; exit 1; }
    else
      git worktree add -b "$BRANCH" "$WT" "origin/$base" >/dev/null 2>&1 || { echo "worktree.sh: worktree add failed" >&2; exit 1; }
    fi
    printf '%s\n' "$WT" ;;
esac
