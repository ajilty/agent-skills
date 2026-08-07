#!/usr/bin/env bash
# shipyard plugin suite (ADR-0038): deterministic checks on the invocation
# contract (explicit-only everywhere) and the generic-seam invariant
# (orchestrate is named in README.md only). Runnable from any cwd; deps within
# the repo baseline: bash, coreutils, yq (v4, mikefarah).
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

skills=(shipyard scope shape spec ship)
for s in "${skills[@]}"; do
  f="skills/$s/SKILL.md"
  if [ ! -f "$f" ]; then err "$f missing"; continue; fi

  name=$(yq --front-matter=extract '.name' "$f")
  if [ "$name" != "$s" ]; then err "$f: name '$name' != '$s'"; fi

  dmi=$(yq --front-matter=extract '.["disable-model-invocation"]' "$f")
  if [ "$dmi" != "true" ]; then err "$f: must set disable-model-invocation: true"; fi

  desc=$(yq --front-matter=extract '.description' "$f")
  if [ -z "$desc" ] || [ "$desc" = "null" ]; then err "$f: missing description"; fi

  if grep -qi 'orchestrate' "$f"; then
    err "$f: names orchestrate (generic-seam invariant: README only)"
  fi

  if ! diff -q references/conventions.md "skills/$s/conventions.md" >/dev/null 2>&1; then
    err "skills/$s/conventions.md missing or out of sync with references/conventions.md (canonical); re-copy it"
  fi

  e="skills/$s/evals/evals.json"
  if [ ! -f "$e" ]; then
    err "$e missing (skill-creator convention: evals live in the skill dir)"
  elif [ "$(yq -oy '.skill_name' "$e")" != "$s" ]; then
    err "$e: skill_name must be '$s'"
  fi

  y="skills/$s/agents/openai.yaml"
  if [ ! -f "$y" ]; then
    err "$y missing (Codex explicit-only sidecar)"
  elif [ "$(yq '.policy.allow_implicit_invocation' "$y")" != "false" ]; then
    err "$y: must set policy.allow_implicit_invocation: false"
  fi
done

if [ ! -f references/conventions.md ]; then err "references/conventions.md missing"; fi
if ! grep -qi 'orchestrate' README.md; then
  err "README.md should name orchestrate as the optional engine (its one allowed place)"
fi

if [ "$fail" -eq 0 ]; then
  echo "shipyard tests: OK"
else
  exit 1
fi
