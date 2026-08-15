#!/usr/bin/env bash
#
# Runs placeholders.sh against a fixture built to look like a repository mid-configuration.
#
# Four of these assertions are review findings kept as tests, because each one made the check
# report a finished run that was not finished, or an unfinished one that was:
#
#   - a GitHub Actions expression read as an unfilled value
#   - a document whose subject is the template counted as carrying values
#   - TEMPLATE.md and the workflow's own header comment, missed by the exclusion list that
#     replaced the first two
#   - a deferred answer sharing a line with a real unfilled value, filed as deferred
#
# The first three are why this takes an allowlist instead of an exclusion list: only the files the
# interview writes are supposed to end up clean, and nothing about a new document can change that.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/placeholders.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n          %s\n' "$1" "${2-}"; }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected [$2], got [$3]"; fi; }

run() { OUT="$("$SCRIPT" --repo "$D" "$@" 2>&1)"; RC=$?; }
field() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p"; }

D="$(mktemp -d)"
mkdir -p "$D/.github/workflows" "$D/.claude/skills/init-project" "$D/docs/specs"

echo "placeholders.sh"

# --- 1. a configured repository -----------------------------------------------------------------
printf '# Project\n\nA real description.\n' > "$D/AGENTS.md"
printf '# Project\n\nA real description.\n' > "$D/README.md"
run
check "configured: exit 0"     "0" "$RC"
check "configured: none found" "0" "$(field unresolved)"

# --- 2. a GitHub expression is not an unfilled value ---------------------------------------------
cat > "$D/.github/workflows/ci.yml" <<'YML'
concurrency:
  group: ci-${{ github.event_name == 'pull_request' && github.ref || github.sha }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
YML
run
check "workflow expressions: exit 0"      "0" "$RC"
check "workflow expressions: not counted" "0" "$(field unresolved)"

# --- 3. documents whose subject is the template are not scanned at all ---------------------------
#
# The exclusion list this replaced covered the first two of these and missed the third, which is
# the finding that turned the design around.
printf 'Stop when a fact still reads {{PLACEHOLDER}}.\n' > "$D/.claude/skills/init-project/SKILL.md"
printf 'The interview fills {{PROJECT_NAME}}.\n'         > "$D/docs/specs/spec.md"
printf 'Every `{{PLACEHOLDER}}` is filled in by /init-project.\n' > "$D/TEMPLATE.md"
run
check "documents about the template: exit 0"      "0" "$RC"
check "documents about the template: not counted" "0" "$(field unresolved)"

# --- 4. a real unfilled value --------------------------------------------------------------------
printf '# {{PROJECT_NAME}}\n\n{{PROJECT_ONE_LINE}}\n' > "$D/README.md"
run
check "unfilled values: exit 1"  "1" "$RC"
check "unfilled values: counted" "2" "$(field unresolved)"

# --- 5. a deferred answer is reported apart from an unfilled one ----------------------------------
printf '# Project\n\nA real description.\n' > "$D/README.md"
printf 'Boundaries: {{TODO}} — block 8\n' > "$D/AGENTS.md"
run
check "deferred answers: exit 0"         "0" "$RC"
check "deferred answers: counted"        "1" "$(field todo)"
check "deferred answers: not unresolved" "0" "$(field unresolved)"

# --- 6. a deferred answer sharing a line with a real one -----------------------------------------
#
# Filing the whole line as deferred reported initialization complete with a template value still in
# the repository.
printf 'Boundaries: {{TODO}} plus {{PROJECT_NAME}}\n' > "$D/AGENTS.md"
run
check "mixed marker line: the real value is counted" "1" "$(field unresolved)"
check "mixed marker line: the deferred one too"      "1" "$(field todo)"
check "mixed marker line: exit 1"                    "1" "$RC"

# --- 7. a placeholder sharing a line with a workflow expression -----------------------------------
printf 'Boundaries: settled\n' > "$D/AGENTS.md"
cat > "$D/.github/workflows/ci.yml" <<'YML'
- run: deploy --sha ${{ github.sha }} --env {{DEPLOY_ENV}}
YML
run
check "mixed expression line: the placeholder survives the strip" "1" "$(field unresolved)"
check "mixed expression line: exit 1"                             "1" "$RC"

# --- 8. an explicit path list overrides the defaults ----------------------------------------------
printf -- '- run: echo done\n' > "$D/.github/workflows/ci.yml"   # clear the previous case
printf '# {{PROJECT_NAME}}\n' > "$D/somewhere-else.md"
run
check "outside the list: not scanned by default" "0" "$(field unresolved)"
run somewhere-else.md
check "outside the list: scanned when named"     "1" "$(field unresolved)"

rm -rf "$D"

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
