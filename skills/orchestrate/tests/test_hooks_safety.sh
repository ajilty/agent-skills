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
