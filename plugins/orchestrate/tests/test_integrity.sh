SK="$HERE/.."   # plugins/orchestrate
SKILLDIR="$SK/skills/orchestrate"
REF="$SKILLDIR/references"

# --- Dependency integrity: every persona `body:` file declared in agents.yaml exists.
#     A typo'd body path silently produces a broken/empty generated agent; the drift
#     guard only diffs OUTPUT, so a missing SOURCE file would not be flagged. Needs yq.
if command -v yq >/dev/null 2>&1; then
  AG="$REF/agents.yaml"
  for p in $(yq '.personas | keys | .[]' "$AG"); do
    b="$(yq ".personas.$p.body" "$AG")"
    if [ -n "$b" ] && [ -f "$REF/$b" ]; then pass; else fail "persona '$p' body file missing: references/$b"; fi
  done
else
  echo "(skip persona-body existence: yq absent)"
fi

# --- Reference integrity: navigable file refs (references/ runtime/ scripts/ commands/,
#     incl. ../-prefixed) in SKILL.md + persona bodies + resume.md must resolve to a
#     real file, relative to the referring file's own directory. Guards the exact class
#     that broke once: a relocate left a stale relative path (scripts/ -> ../../scripts/),
#     caught then only by a human reviewer. Placeholders (<name>, *) are skipped.
refbad=0
for f in "$SKILLDIR/SKILL.md" "$REF"/personas/*.md "$REF/resume.md"; do
  [ -f "$f" ] || continue
  d="$(dirname "$f")"
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "$ref" in *'<'*|*'*'*) continue;; esac   # skip placeholder/glob tokens
    [ -e "$d/$ref" ] || { refbad=1; echo "  broken ref in ${f#"$SK"/}: $ref" >&2; }
  done < <(grep -oE '(\.\./)*(references|runtime|scripts|commands)/[A-Za-z0-9_./-]+\.(sh|md|json|yaml)' "$f" | sort -u)
done
[ "$refbad" = 0 ] && pass || fail "SKILL/persona internal file references resolve (nav integrity)"
