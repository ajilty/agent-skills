# Existing PostToolUse syntax validator: smoke coverage so the suite guards it too.
V="$HERE/../hooks/validate-syntax.sh"
R="$(mktemp_repo)"
printf '{"a":1}\n' > "$R/ok.json"; printf '{"a":\n' > "$R/bad.json"
printf -- '---\nname: x\n---\nbody\n' > "$R/ok.md"; printf -- '---\nname: [\n---\nbody\n' > "$R/bad.md"
printf 'no frontmatter\n' > "$R/plain.md"
run_hook "$V" "$(file_payload "$R/ok.json")"; assert_eq "$RC" 0 "valid json -> 0"
run_hook "$V" "$(file_payload "$R/bad.json")"; assert_eq "$RC" 2 "invalid json -> 2"
run_hook "$V" "$(file_payload "$R/plain.md")"; assert_eq "$RC" 0 "md without frontmatter -> 0"
if command -v yq >/dev/null 2>&1 && yq --version 2>&1 | grep -qE 'mikefarah|version v?4\.'; then
  run_hook "$V" "$(file_payload "$R/ok.md")"; assert_eq "$RC" 0 "valid frontmatter -> 0"
  run_hook "$V" "$(file_payload "$R/bad.md")"; assert_eq "$RC" 2 "invalid frontmatter -> 2"
else
  skip "yq v4 absent: frontmatter checks untested"
fi
