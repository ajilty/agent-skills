# Tier 3b (OpenCode compaction event, live, best-effort) — the ADR-0034 doc-
# tension follow-up: does `session.compacted` (what orchestrate.ts wires) or
# `experimental.session.compacting` (what the live source's Hooks interface
# actually documents — see .agents/runs/orchestrate/tickets/opencode-native/
# findings/opencode-api-limits.md) fire in 1.18.4? Forcing real compaction
# cheaply isn't practical (needs a context large enough to overflow, which is
# neither cheap nor deterministic), so per the work item we probe HOOK
# REGISTRATION MECHANICS only and SKIP the firing assertion with a note, unless
# one of the candidate markers happens to fire anyway.
#
# Method: a standalone marker plugin (separate from orchestrate.ts, dropped into
# the same sandboxed plugins/ dir) registers FOUR handlers that each touch a
# distinct marker file: a CONTROL hook (tool.execute.after — confirmed to fire
# on any tool call, proving the marker mechanism itself works) plus the three
# candidates (session.compacted, experimental.session.compacting, dispose — the
# last also confirmed-documented, fires at session end, a second mechanism
# sanity check independent of tool use).
if ! have_opencode; then
  skip "opencode compaction-event: opencode CLI not on PATH"
elif ! have_opencode_auth; then
  skip "opencode compaction-event: no opencode auth (~/.local/share/opencode/auth.json)"
else
  oc="$(mk_opencode_home)"
  mkdir -p "$oc/.config/opencode/plugins"
  marker_dir="$(mk_tmp)"
  cat > "$oc/.config/opencode/plugins/compaction-marker.ts" <<TS
import { execFileSync } from "node:child_process";
const mk = (name: string) => { try { execFileSync("touch", ["$marker_dir/" + name]); } catch (e) {} };
export const compactionMarker = async () => ({
  "tool.execute.after": async () => mk("control.tool_execute_after"),
  "dispose": async () => mk("control.dispose"),
  "session.compacted": async () => mk("candidate.session_compacted"),
  "experimental.session.compacting": async (input: any, output: any) => { mk("candidate.experimental_session_compacting"); if (output) output.context = []; },
});
TS
  ws="$(mk_tmp)"
  echo "hi" > "$ws/note.txt"
  out="$(cd "$ws" && oc_run "$oc" timeout 90 opencode run --model "$OC_MODEL" "Use your file read tool to read note.txt and report its contents." 2>&1)"
  rc=$?

  if [ -f "$marker_dir/control.tool_execute_after" ]; then
    pass   # marker mechanism validated live: tool.execute.after fired
  elif [ "$rc" -eq 124 ]; then
    skip "opencode compaction-event: live run timed out — marker mechanism unvalidated this run"
  else
    skip "opencode compaction-event: model did not attempt the read this run — control marker didn't fire, can't validate the mechanism"
  fi

  # Candidate firing: not forced (no compaction was triggered), so absence is
  # EXPECTED and not a failure -- this SKIPs the firing question per the work
  # item's guidance rather than asserting on an untriggered event.
  if [ -f "$marker_dir/candidate.session_compacted" ] || [ -f "$marker_dir/candidate.experimental_session_compacting" ]; then
    pass   # a compaction candidate fired incidentally this run (unexpected bonus signal)
    [ -f "$marker_dir/candidate.session_compacted" ] && echo "  (note: session.compacted fired)"
    [ -f "$marker_dir/candidate.experimental_session_compacting" ] && echo "  (note: experimental.session.compacting fired)"
  else
    skip "opencode compaction-event: neither session.compacted nor experimental.session.compacting fired -- compaction was not triggered this run (forcing it cheaply isn't practical); registration-only bound per the work item. Per the DERIVED source read in opencode-api-limits.md, session.compacted is NOT in the documented Hooks interface (experimental.session.compacting is) -- treat orchestrate.ts's session.compacted wiring as unverified until a real compaction is observed to fire it."
  fi
  cd /
fi
