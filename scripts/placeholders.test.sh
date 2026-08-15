#!/usr/bin/env bash
#
# Runs placeholders.sh against a fixture built to look like a half-configured repository.
#
# The two assertions that matter most are the ones that produced the script: a GitHub workflow
# expression is not a placeholder, and a skill that documents placeholders is not carrying them.
# A check that gets either wrong can never report a finished run, and an agent trying to satisfy it
# would edit a workflow's own logic.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/placeholders.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n          %s\n' "$1" "${2-}"; }

check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected [$2], got [$3]"; fi; }

run() { OUT="$("$SCRIPT" --repo "$D" 2>&1)"; RC=$?; }
field() { printf '%s\n' "$OUT" | sed -n "s/^$1=//p"; }

D="$(mktemp -d)"
mkdir -p "$D/.github/workflows" "$D/.claude/skills/init-project" "$D/docs/specs" "$D/docs/decisions"

echo "placeholders.sh"

# --- 1. a clean repository ----------------------------------------------------------------------
printf '# Project\n\nA real description.\n' > "$D/AGENTS.md"
run
check "clean: exit 0"      "0" "$RC"
check "clean: none found"  "0" "$(field unresolved)"

# --- 2. GitHub expressions are not placeholders --------------------------------------------------
#
# This is the case that made the one-liner unusable: the workflow is correct and must stay correct.
cat > "$D/.github/workflows/ci.yml" <<'YML'
concurrency:
  group: ci-${{ github.event_name == 'pull_request' && github.ref || github.sha }}
  cancel-in-progress: ${{ github.event_name == 'pull_request' }}
YML
run
check "workflow expressions: exit 0"    "0" "$RC"
check "workflow expressions: not counted" "0" "$(field unresolved)"

# --- 3. a skill describing placeholders is not carrying them -------------------------------------
cat > "$D/.claude/skills/init-project/SKILL.md" <<'MD'
Stop when a fact still reads {{PLACEHOLDER}}, and report every {{TODO}} left standing.
MD
printf 'The interview fills {{PROJECT_NAME}} and the rest.\n' > "$D/docs/specs/spec.md"
run
check "documentation about placeholders: exit 0"     "0" "$RC"
check "documentation about placeholders: not counted" "0" "$(field unresolved)"

# --- 4. a real unfilled placeholder ---------------------------------------------------------------
printf '# {{PROJECT_NAME}}\n\n{{PROJECT_ONE_LINE}}\n' > "$D/README.md"
run
check "unfilled values: exit 1"  "1" "$RC"
check "unfilled values: counted" "2" "$(field unresolved)"

# --- 5. a deferred answer is reported apart from an unfilled one ----------------------------------
printf '# Project\n\nA real description.\n' > "$D/README.md"
printf 'Boundaries: {{TODO}} — block 8\n' > "$D/AGENTS.md"
run
check "deferred answers: exit 0"        "0" "$RC"
check "deferred answers: counted apart" "1" "$(field todo)"
check "deferred answers: not unresolved" "0" "$(field unresolved)"

# --- 6. a placeholder on the same line as a workflow expression -----------------------------------
#
# Stripping the expression must not take the placeholder with it.
cat > "$D/.github/workflows/deploy.yml" <<'YML'
- run: deploy --sha ${{ github.sha }} --env {{DEPLOY_ENV}}
YML
run
check "mixed line: the placeholder survives the strip" "1" "$(field unresolved)"
check "mixed line: exit 1"                             "1" "$RC"

rm -rf "$D"

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
