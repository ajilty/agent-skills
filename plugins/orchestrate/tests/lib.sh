#!/usr/bin/env bash
# Zero-dependency assertion helpers for orchestrate runtime tests.
set -uo pipefail
PASS=0; FAIL=0
pass(){ PASS=$((PASS+1)); }
fail(){ FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1" >&2; }
assert_eq(){ [ "$1" = "$2" ] && pass || fail "${3:-} (got '$1' want '$2')"; }
assert_exit(){ local want="$1"; shift; "$@" >/dev/null 2>&1; local got=$?; [ "$got" = "$want" ] && pass || fail "exit want=$want got=$got: $*"; }
assert_file(){ [ -f "$1" ] && pass || fail "missing file $1"; }
assert_no_file(){ [ ! -f "$1" ] && pass || fail "unexpected file $1"; }
mktemp_repo(){ local d; d="$(mktemp -d)"; ( cd "$d" && git init -q && git config user.email t@t && git config user.name t && mkdir -p .agents/runs/orchestrate ); printf '%s\n' "$d"; }
# The yaml-parsing checks need mikefarah yq v4. The Python (kislyuk) yq answers
# `command -v yq` too but emits JSON-quoted scalars, so a presence-only guard
# turns those checks into 36 misleading failures. Probe the flavor, not presence.
have_yq4(){ command -v yq >/dev/null 2>&1 && yq --version 2>&1 | grep -qE 'mikefarah|version v?4\.'; }
YQ4_SKIP="yq v4 (mikefarah) absent$(command -v yq >/dev/null 2>&1 && echo ' (found a non-v4 yq flavor)')"
