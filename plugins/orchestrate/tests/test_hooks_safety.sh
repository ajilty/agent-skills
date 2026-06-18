RT="$HERE/../scripts/runtime/hooks"
# Claude Code PreToolUse contract: ALLOW = exit 0 with NO stdout; DENY = exit 2
# (reason on stderr). Emitting decision JSON trips CC's hook-output validation, so
# allow paths must be stdout-silent. These tests lock that contract + the rule that
# a hook NEVER errors on missing env (the live failure that broke the session).

# --- deny-heldout-read.sh ---
o="$(PERSONA= HELDOUT_ROOT= bash "$RT/deny-heldout-read.sh" 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "deny-heldout: exit 0 when unconfigured (no :? abort)"
assert_eq "$o" "" "deny-heldout: silent stdout on allow (no JSON to fail validation)"
PERSONA=verifier HELDOUT_ROOT=/tmp/ho RESOLVED_PATH=/tmp/ho/probe bash "$RT/deny-heldout-read.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "deny-heldout: allows non-writers even under HELDOUT_ROOT"
PERSONA=implementer HELDOUT_ROOT=/tmp/ho RESOLVED_PATH=/tmp/ho/secret bash "$RT/deny-heldout-read.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "deny-heldout: denies writer under HELDOUT_ROOT with exit 2"
PERSONA=implementer HELDOUT_ROOT=/tmp/ho RESOLVED_PATH= bash "$RT/deny-heldout-read.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "deny-heldout: allows writer bash (empty path)"

# --- keep-on-branch.sh ---
o="$(PERSONA= TOOL_INPUT='git checkout -b foo' bash "$RT/keep-on-branch.sh" 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "keep-on-branch: exit 0 for non-implementer"
assert_eq "$o" "" "keep-on-branch: silent stdout on allow"
PERSONA=implementer TOOL_INPUT='git checkout -b foo' bash "$RT/keep-on-branch.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "keep-on-branch: denies implementer branch-create with exit 2"
PERSONA=implementer ASSIGNED_BRANCH= TOOL_INPUT='git commit -m x' bash "$RT/keep-on-branch.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "keep-on-branch: allows commit when no assigned branch"

# --- gate-prod-apply.sh ---
o="$(PERSONA= bash "$RT/gate-prod-apply.sh" 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "gate: exit 0 for non-actuator"
assert_eq "$o" "" "gate: silent stdout on allow"
PERSONA=actuator TICKET= PROD_TARGETS= bash "$RT/gate-prod-apply.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "gate: exit 0 for actuator with no ticket/targets (no :? abort)"

# --- stdin (Claude Code) path: identity + tool input arrive as stdin JSON ---
if command -v jq >/dev/null 2>&1; then
  printf '{"agent_type":"implementer","tool_name":"Read","tool_input":{"file_path":"/tmp/ho/secret"}}' \
    | HELDOUT_ROOT=/tmp/ho bash "$RT/deny-heldout-read.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "deny-heldout: denies writer via stdin agent_type+file_path (CC path)"
  printf '{"agent_type":"verifier","tool_input":{"file_path":"/tmp/ho/probe"}}' \
    | HELDOUT_ROOT=/tmp/ho bash "$RT/deny-heldout-read.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "deny-heldout: allows non-writer via stdin (CC path)"
  printf '{"agent_type":"implementer","tool_name":"Bash","tool_input":{"command":"git checkout -b x"}}' \
    | bash "$RT/keep-on-branch.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "keep-on-branch: denies implementer branch-create via stdin (CC path)"
  printf '{"tool_name":"Bash","tool_input":{"command":"git checkout -b x"}}' \
    | bash "$RT/keep-on-branch.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "keep-on-branch: allows main session (no agent_type) via stdin (CC path)"
  printf '{"agent_type":"actuator","tool_input":{"command":"terraform apply"}}' \
    | bash "$RT/gate-prod-apply.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "gate: detects actuator via stdin; no prod targets -> allow"
  # stdin DENY path is stderr-only: empty stdout even when it blocks (else "Invalid input")
  o="$(printf '{"agent_type":"implementer","tool_input":{"file_path":"/tmp/ho/x"}}' | HELDOUT_ROOT=/tmp/ho bash "$RT/deny-heldout-read.sh" 2>/dev/null)"
  assert_eq "$o" "" "deny-heldout: empty stdout on stdin DENY (stderr-only)"
  # stdin identity takes PRECEDENCE over env: agent_type=verifier beats PERSONA=implementer -> allow
  printf '{"agent_type":"verifier","tool_input":{"file_path":"/tmp/ho/x"}}' \
    | PERSONA=implementer HELDOUT_ROOT=/tmp/ho RESOLVED_PATH=/tmp/ho/x bash "$RT/deny-heldout-read.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "deny-heldout: stdin agent_type overrides env PERSONA"
else
  echo "(skip stdin/CC-path hook tests: jq absent)"
fi
# malformed JSON on stdin must degrade safely (no crash) — clean env -> allow
printf 'not json{' | bash "$RT/deny-heldout-read.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "deny-heldout: malformed stdin JSON degrades to allow (no crash)"
# no hang on EOF stdin (the [ -t 0 ] guard) — bounded by timeout
if command -v timeout >/dev/null 2>&1; then
  timeout 5 bash "$RT/deny-heldout-read.sh" </dev/null >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "deny-heldout: no hang on EOF stdin (exit 0 within timeout)"
fi

# --- GENERALIZED session-safety floor: EVERY hook must exit 0 when fired with no
# orchestrate context env (the real "main router runs a tool" condition that broke
# the session). Auto-covers any hook added later. ---
d="$(mktemp_repo)"; cd "$d"
for h in "$RT"/*.sh; do
  name="$(basename "$h")"
  env -u PERSONA -u HELDOUT_ROOT -u ASSIGNED_BRANCH -u TICKET -u PROD_TARGETS \
      -u TOOL_INPUT -u RESOLVED_PATH -u CODEX_TOOL_PATH -u CODEX_TOOL_INPUT \
      -u CLAUDE_AGENT_TYPE -u CODEX_AGENT -u DISPATCH_ID \
      bash "$h" </dev/null >/dev/null 2>&1
  assert_eq "$?" "0" "hook $name exits 0 with no orchestrate env (session-safety floor)"
done
cd /; rm -rf "$d"
