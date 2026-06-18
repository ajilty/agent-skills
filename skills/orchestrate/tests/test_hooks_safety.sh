RT="$HERE/../scripts/runtime/hooks"

# --- deny-heldout-read.sh: must never break the session; self-guard + degrade ---
# main session (no persona) + HELDOUT_ROOT unset -> allow, valid JSON, exit 0
out="$(PERSONA= HELDOUT_ROOT= bash "$RT/deny-heldout-read.sh" 2>&1)"; rc=$?
assert_eq "$rc" "0" "deny-heldout exits 0 when unconfigured (no :? abort)"
printf '%s' "$out" | grep -q '"decision":"allow"' && pass || fail "deny-heldout allows when unconfigured (got: $out)"
# non-writer persona -> allow even when HELDOUT_ROOT set (Verifier/router must read it)
out="$(PERSONA=verifier HELDOUT_ROOT=/tmp/ho RESOLVED_PATH=/tmp/ho/probe bash "$RT/deny-heldout-read.sh")"
printf '%s' "$out" | grep -q '"decision":"allow"' && pass || fail "deny-heldout allows non-writers under HELDOUT_ROOT"
# implementer reading under HELDOUT_ROOT -> deny
out="$(PERSONA=implementer HELDOUT_ROOT=/tmp/ho RESOLVED_PATH=/tmp/ho/secret bash "$RT/deny-heldout-read.sh")"
printf '%s' "$out" | grep -q '"decision":"deny"' && pass || fail "deny-heldout denies writer under HELDOUT_ROOT"
# implementer Bash (no resolved path) -> allow (don't block all writer commands)
out="$(PERSONA=implementer HELDOUT_ROOT=/tmp/ho RESOLVED_PATH= bash "$RT/deny-heldout-read.sh")"; rc=$?
assert_eq "$rc" "0" "deny-heldout exits 0 on writer bash"
printf '%s' "$out" | grep -q '"decision":"allow"' && pass || fail "deny-heldout allows writer bash (empty path)"

# --- keep-on-branch.sh: self-guard on implementer; degrade when no assigned branch ---
# non-implementer (router) -> allow branch/commit
out="$(PERSONA= TOOL_INPUT='git checkout -b foo' bash "$RT/keep-on-branch.sh")"; rc=$?
assert_eq "$rc" "0" "keep-on-branch exits 0 for non-implementer"
printf '%s' "$out" | grep -q '"decision":"allow"' && pass || fail "keep-on-branch allows non-implementer branch-create"
# implementer branch-create -> deny
out="$(PERSONA=implementer TOOL_INPUT='git checkout -b foo' bash "$RT/keep-on-branch.sh")"
printf '%s' "$out" | grep -q '"decision":"deny"' && pass || fail "keep-on-branch denies implementer branch-create"
# implementer commit with ASSIGNED_BRANCH unset -> allow (can't enforce; don't break)
out="$(PERSONA=implementer ASSIGNED_BRANCH= TOOL_INPUT='git commit -m x' bash "$RT/keep-on-branch.sh")"; rc=$?
assert_eq "$rc" "0" "keep-on-branch exits 0 on implementer commit w/o assigned branch"
printf '%s' "$out" | grep -q '"decision":"allow"' && pass || fail "keep-on-branch allows commit when no assigned branch"

# --- gate-prod-apply.sh: must not :? abort for an actuator missing TICKET context ---
out="$(PERSONA=actuator TICKET= PROD_TARGETS= bash "$RT/gate-prod-apply.sh" 2>&1)"; rc=$?
assert_eq "$rc" "0" "gate-prod-apply exits 0 for actuator with no ticket/targets (no :? abort)"

# --- GENERALIZED session-safety floor: EVERY hook must exit 0 when fired with no
# orchestrate context env set (the real "main router runs a tool" condition that
# broke the session). This auto-covers any hook added later. ---
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
