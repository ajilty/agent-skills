# Tier 3c (live) — TEST THE GATE JUDGMENT (O6 front-door clarify-gate, §2b). Unlike
# test_clarify_lane (which instructs the router to journal a clarify, testing plumbing),
# this tests the JUDGMENT: give a bare goal with NO hint to clarify, and see whether the
# gate fires on its own at the right time.
#
# Case FUZZY: a goal with no acceptance oracle nameable as-stated ("add rate limiting" —
#   limit/scope/backend/response-code all unstated). The gate MUST fire: a `clarify` event
#   must appear BEFORE any implementer dispatch (err-toward-asking), and ideally the lane
#   HALTs (no implementer at all) since the session is non-interactive. The failure this
#   guards is real and was observed in a probe BEFORE the gate existed: a premium Planner
#   invents a plausible-but-wrong spec and an Implementer builds it with zero clarify (the
#   silent-rework mode). Implementer-with-no-clarify on a fuzzy goal = the gate FAILED.
#
# Case CLEAR: a fully-specified spec. The gate must NOT over-fire — no `clarify` before
#   the first dispatch — or every clear goal pays an interruption tax (the O7 failure mode).
#
# We seed the real clarification skills so first-present selection is faithful.
if ! have_claude; then
  skip "tier3 clarify-gate: claude CLI not on PATH"
elif ! have_live_auth; then
  skip "tier3 clarify-gate: no live auth"
else
  _seed_skills(){ mkdir -p "$1/.claude/skills"; local s
    for s in grill-with-docs grill-me brainstorming; do
      [ -d "$HOME/.claude/skills/$s" ] && cp -r "$HOME/.claude/skills/$s" "$1/.claude/skills/" 2>/dev/null
    done; }
  _run(){ # <repo> <home> <goal> -> drives the router headless
    printf '%s' "$3" | ( cd "$1" && HOME="$2" timeout 480 claude -p \
      --plugin-dir "$PLUGIN_DIR" --allowedTools "Read,Grep,Glob,Write,Edit,Bash,Task,Skill" ) >/dev/null 2>&1; }
  _firstline(){ grep -nE "$2" "$1" 2>/dev/null | head -1 | cut -d: -f1; }

  # --- Case FUZZY -------------------------------------------------------------------
  hf="$(mk_authed_home)"; rf="$(mk_repo)"; _seed_skills "$hf"
  printf 'def handle_request(req: dict) -> dict:\n    return {"status": "ok"}\n' > "$rf/api.py"
  ( cd "$rf" && git add -A && git commit -q -m seed )
  _run "$rf" "$hf" "Use the orchestrate skill to deliver this goal end to end: add rate limiting to the API in api.py. Follow the skill's full process."
  bf="$rf/.agents/runs/orchestrate/board.jsonl"
  cl="$(_firstline "$bf" '"event":"clarify"')"
  im="$(_firstline "$bf" '"event":"dispatched".*"persona":"implementer"')"
  if [ -n "$cl" ] && { [ -z "$im" ] || [ "$cl" -lt "$im" ]; }; then
    pass   # gate fired: clarify before any build
    [ -z "$im" ] && echo "  (FUZZY: HALT-open — no implementer dispatched on the unresolved goal)"
  elif [ -n "$im" ] && [ -z "$cl" ]; then
    fail "clarify-gate FUZZY: implementer dispatched with NO clarify (silent-rework — gate did not fire)"
  else
    skip "clarify-gate FUZZY: router neither clarified nor built this run (declined / didn't reach dispatch)"
  fi

  # --- Case CLEAR (over-fire guard) -------------------------------------------------
  hc="$(mk_authed_home)"; rc="$(mk_repo)"; _seed_skills "$hc"
  cat > "$rc/SPEC.md" <<'SPEC'
# parse_duration
Implement parse_duration(s: str) -> int in duration.py.
Input like "1h30m","45m","90s". Output total SECONDS. Units h=3600 m=60 s=1, order h,m,s,
any subset. Empty/malformed -> ValueError. Acceptance: the stated cases map to their seconds.
SPEC
  printf 'def parse_duration(s: str) -> int:\n    raise NotImplementedError\n' > "$rc/duration.py"
  ( cd "$rc" && git add -A && git commit -q -m seed )
  _run "$rc" "$hc" "Use the orchestrate skill to deliver this goal end to end: implement parse_duration in duration.py per SPEC.md. Follow the skill's full process."
  bc="$rc/.agents/runs/orchestrate/board.jsonl"
  clc="$(_firstline "$bc" '"event":"clarify"')"
  dpc="$(_firstline "$bc" '"event":"dispatched"')"
  if [ -z "$clc" ] && [ -n "$dpc" ]; then
    pass   # no over-fire: a fully-specified goal proceeded without a clarify
  elif [ -n "$clc" ] && { [ -z "$dpc" ] || [ "$clc" -lt "$dpc" ]; }; then
    fail "clarify-gate CLEAR: gate OVER-FIRED — clarified a fully-specified goal before dispatching (interruption tax)"
  else
    skip "clarify-gate CLEAR: router didn't reach a dispatch this run (declined)"
  fi
  cd /
fi
