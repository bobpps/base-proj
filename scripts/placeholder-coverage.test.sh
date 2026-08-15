#!/usr/bin/env bash
#
# Asserts that every placeholder the template carries is something the interview knows how to fill.
#
# This exists because of a pattern rather than a bug. Review rounds kept finding the same shape:
# a `{{VALUE}}` sitting in AGENTS.md or README.md that no question produces — SETUP_COMMANDS,
# CMD_FORMAT, CMD_SUPPORTING, SCOPE, the Node version. Each was reported separately, fixed
# separately, and the next round found another, because the interview's question set was written
# from a specification rather than from the placeholders it has to answer.
#
# So compare the two lists mechanically. A placeholder with no mention anywhere in the skill is a
# question nobody will be asked, and it surfaces at the end of somebody's real initialization as
# either an invented value or a failed verification.
#
# The reverse direction is not checked. A skill may discuss a value it does not write.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/.claude/skills/init-project"
MAP="$SKILL/references/writing.md"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n          %s\n' "$1" "${2-}"; }

echo "placeholder coverage"

[ -f "$MAP" ] || { fail "the writing map is present" "$MAP missing"; echo; echo "  $PASS passed, $FAIL failed"; exit 1; }

# The files the interview fills. `.template` included: the workflow is renamed during the run, and
# its placeholders are the run's job either way.
FILLED=(AGENTS.md CLAUDE.md README.md .github/workflows/ci.yml.template)

names="$(
  for f in "${FILLED[@]}"; do
    [ -f "$ROOT/$f" ] || continue
    # Skip `${{ … }}`, which belongs to GitHub Actions and is not the interview's to fill.
    sed 's/\${{[^}]*}}//g' "$ROOT/$f" | grep -o '{{[A-Z_][A-Z0-9_]*}}' || true
  done | sed 's/[{}]//g' | LC_ALL=C sort -u
)"

total=0
missing=""
for name in $names; do
  total=$((total + 1))
  # A row of the map, not a mention anywhere. Two weaker forms were tried and both passed on
  # coincidences: a fixed-string search found `SCOPE` inside `OUT_OF_SCOPE`, and a whole-token
  # search found it in the paragraph *about* missing placeholders. Neither tells anyone which
  # question fills the value, which is the only thing this check is for.
  if ! grep -qE "^\| .*\`$name\`" "$MAP"; then
    missing="$missing $name"
  fi
done

if [ "$total" -gt 0 ]; then
  pass "the template carries placeholders to check ($total distinct)"
else
  fail "the template carries placeholders to check" "found none; the extraction is broken"
fi

if [ -z "$missing" ]; then
  pass "every placeholder has a row in the writing map"
else
  fail "every placeholder has a row in the writing map" "no question produces:$missing"
fi

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
