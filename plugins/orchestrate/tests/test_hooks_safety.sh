RT="$HERE/../skills/orchestrate/runtime/hooks"
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
PERSONA=actuator HELDOUT_ROOT=/tmp/ho RESOLVED_PATH=/tmp/ho/oracle bash "$RT/deny-heldout-read.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "deny-heldout: denies the ACTUATOR under HELDOUT_ROOT too (agents.yaml applies_to)"

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

# --- write-scope.sh (planner spec/ADR write confinement; fail-closed) ---
o="$(PERSONA= bash "$RT/write-scope.sh" 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "write-scope: exit 0 for non-planner"
assert_eq "$o" "" "write-scope: silent stdout on allow"
PERSONA=planner RESOLVED_PATH=docs/specs/2026-x.md bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "write-scope: allows planner write to docs/specs/**"
PERSONA=planner RESOLVED_PATH=docs/adr/0007-x.md bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "write-scope: allows planner write to docs/adr/**"
PERSONA=planner RESOLVED_PATH=.agents/runs/orchestrate/tickets/T1/spec.md bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "write-scope: allows planner write to the per-ticket artifact dir"
PERSONA=planner RESOLVED_PATH=/repo/docs/adr/0007-x.md bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "write-scope: allows absolute path under docs/adr/**"
PERSONA=planner RESOLVED_PATH=src/main.py bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "write-scope: denies planner write outside spec/ADR (exit 2)"
o="$(PERSONA=planner RESOLVED_PATH=src/main.py bash "$RT/write-scope.sh" 2>/dev/null)"
assert_eq "$o" "" "write-scope: empty stdout on DENY (stderr-only)"
PERSONA=planner RESOLVED_PATH= bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "write-scope: fail-closed on planner with unresolvable path (deny)"
PERSONA=implementer RESOLVED_PATH=src/main.py bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "write-scope: self-guards — only the planner is scoped (implementer allowed)"
PERSONA=planner RESOLVED_PATH='docs/specs/../../src/evil.py' bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "write-scope: denies path traversal (..) out of an allowed prefix"

# --- run-scope.sh (verifier tests-only: deny workspace/git-mutating Bash) ---
o="$(PERSONA= bash "$RT/run-scope.sh" 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "run-scope: exit 0 for non-verifier"
assert_eq "$o" "" "run-scope: silent stdout on allow"
PERSONA=verifier TOOL_INPUT='bash tests/run.sh' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "run-scope: allows the verifier to run the test suite"
PERSONA=verifier TOOL_INPUT='pytest -q 2>&1' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "run-scope: allows a test run with benign 2>&1 redirect"
PERSONA=verifier TOOL_INPUT='grep -rn foo src' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "run-scope: allows read-only inspection (grep)"
PERSONA=verifier TOOL_INPUT='confirm and rearm' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "run-scope: no false-positive on substrings (confirm/rearm not rm/mv)"
PERSONA=verifier TOOL_INPUT='git checkout -- .' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "run-scope: denies git working-tree mutation (exit 2)"
PERSONA=verifier TOOL_INPUT='echo pass > tests/result.txt' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "run-scope: denies output redirection to a file"
PERSONA=verifier TOOL_INPUT='sed -i s/x/y/ tests/t.py' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "run-scope: denies in-place edit (sed -i)"
PERSONA=verifier TOOL_INPUT='rm tests/t.py' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "run-scope: denies rm"
o="$(PERSONA=verifier TOOL_INPUT='rm tests/t.py' bash "$RT/run-scope.sh" 2>/dev/null)"
assert_eq "$o" "" "run-scope: empty stdout on DENY (stderr-only)"
PERSONA=implementer TOOL_INPUT='echo x > src/foo.py' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "run-scope: self-guards — only the verifier is scoped (implementer writes freely)"
PERSONA=verifier TOOL_INPUT='git -C . checkout -- .' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "run-scope: denies git mutation with intervening -C option"
PERSONA=verifier TOOL_INPUT='git -C . reset --hard' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "run-scope: denies git reset --hard behind -C"
PERSONA=verifier TOOL_INPUT='git status' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "run-scope: allows read-only git status (no over-denial)"
PERSONA=verifier TOOL_INPUT='git diff HEAD' bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "run-scope: allows read-only git diff"

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
  printf '{"agent_type":"planner","tool_name":"Write","tool_input":{"file_path":"src/x.py"}}' \
    | bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "write-scope: denies planner write to src via stdin (CC path)"
  printf '{"agent_type":"planner","tool_name":"Write","tool_input":{"file_path":"docs/adr/0007-x.md"}}' \
    | bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "write-scope: allows planner docs/adr write via stdin (CC path)"
  o="$(printf '{"agent_type":"planner","tool_input":{"file_path":"src/x.py"}}' | bash "$RT/write-scope.sh" 2>/dev/null)"
  assert_eq "$o" "" "write-scope: empty stdout on stdin DENY (stderr-only)"
  printf '{"agent_type":"verifier","tool_name":"Bash","tool_input":{"command":"rm tests/t.py"}}' \
    | bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "run-scope: denies verifier rm via stdin (CC path)"
  printf '{"agent_type":"verifier","tool_name":"Bash","tool_input":{"command":"bash tests/run.sh"}}' \
    | bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "run-scope: allows verifier test run via stdin (CC path)"
  # stdin DENY path is stderr-only: empty stdout even when it blocks (else "Invalid input")
  o="$(printf '{"agent_type":"implementer","tool_input":{"file_path":"/tmp/ho/x"}}' | HELDOUT_ROOT=/tmp/ho bash "$RT/deny-heldout-read.sh" 2>/dev/null)"
  assert_eq "$o" "" "deny-heldout: empty stdout on stdin DENY (stderr-only)"
  # stdin identity takes PRECEDENCE over env: agent_type=verifier beats PERSONA=implementer -> allow
  printf '{"agent_type":"verifier","tool_input":{"file_path":"/tmp/ho/x"}}' \
    | PERSONA=implementer HELDOUT_ROOT=/tmp/ho RESOLVED_PATH=/tmp/ho/x bash "$RT/deny-heldout-read.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "deny-heldout: stdin agent_type overrides env PERSONA"
  # --- REGRESSION (caught by Tier 3b live eval): the CC plugin delivers a NAMESPACED
  #     agent_type, e.g. "orchestrate:actuator" — not the bare persona. Every
  #     persona-guarded hook must normalize the namespace, else the whole hook-enforced
  #     safety layer silently no-ops under the plugin. One per guarded hook:
  printf '{"agent_type":"orchestrate:implementer","tool_name":"Read","tool_input":{"file_path":"/tmp/ho/secret"}}' \
    | HELDOUT_ROOT=/tmp/ho bash "$RT/deny-heldout-read.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "deny-heldout: denies plugin-namespaced orchestrate:implementer"
  printf '{"agent_type":"orchestrate:implementer","tool_name":"Bash","tool_input":{"command":"git checkout -b x"}}' \
    | bash "$RT/keep-on-branch.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "keep-on-branch: denies plugin-namespaced orchestrate:implementer branch-create"
  printf '{"agent_type":"orchestrate:planner","tool_name":"Write","tool_input":{"file_path":"src/x.py"}}' \
    | bash "$RT/write-scope.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "write-scope: denies plugin-namespaced orchestrate:planner write to src"
  printf '{"agent_type":"orchestrate:verifier","tool_name":"Bash","tool_input":{"command":"rm tests/t.py"}}' \
    | bash "$RT/run-scope.sh" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "run-scope: denies plugin-namespaced orchestrate:verifier rm"
  gd="$(mktemp -d)"; mkdir -p "$gd/.agents/runs/orchestrate"
  printf '{"agent_type":"orchestrate:actuator","tool_input":{"command":"terraform apply"}}' \
    | ( cd "$gd" && TICKET=T1 PROD_TARGETS="tfstate:prod/db" bash "$RT/gate-prod-apply.sh" ) >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "gate: denies plugin-namespaced orchestrate:actuator with unacked prod target"
  rm -rf "$gd"
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
