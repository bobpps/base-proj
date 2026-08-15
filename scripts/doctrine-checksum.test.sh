#!/usr/bin/env bash
#
# Runs doctrine-checksum.sh against a real directory.
#
# The assertions are the four ways a doctrine file can move — edited, added, deleted, renamed —
# because a checksum that misses any of them would let `init-project` reach the one layer it must
# never touch while reporting that it had not.

set -uo pipefail

SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/doctrine-checksum.sh"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n          %s\n' "$1" "${2-}"; }

sum() { "$SCRIPT" --repo "$D" --dir doctrine | sed -n 's/^doctrine=//p'; }

changed() { if [ "$2" != "$3" ]; then pass "$1"; else fail "$1" "checksum did not move"; fi; }
same()    { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected no move"; fi; }

D="$(mktemp -d)"
mkdir -p "$D/doctrine" "$D/elsewhere"
printf 'the one rule\n' > "$D/doctrine/evidence.md"
printf 'five axes\n'    > "$D/doctrine/failure-axes.md"

echo "doctrine-checksum.sh"

A="$(sum)"; B="$(sum)"
same "stable when nothing moved" "$A" "$B"

BEFORE="$(sum)"
printf 'the one rule, softened\n' > "$D/doctrine/evidence.md"
changed "an edited rule moves it" "$BEFORE" "$(sum)"

BEFORE="$(sum)"
printf 'a rule nobody agreed to\n' > "$D/doctrine/extra.md"
changed "an added file moves it" "$BEFORE" "$(sum)"

BEFORE="$(sum)"
rm "$D/doctrine/extra.md"
changed "a deleted file moves it" "$BEFORE" "$(sum)"

# A rename keeps every byte of content and changes only the path, so a checksum over contents alone
# would report the doctrine untouched. The paths are hashed for exactly this case.
BEFORE="$(sum)"
mv "$D/doctrine/failure-axes.md" "$D/doctrine/axes.md"
changed "a renamed file moves it" "$BEFORE" "$(sum)"

BEFORE="$(sum)"
printf 'project specific\n' > "$D/elsewhere/AGENTS.md"
same "a change outside the directory does not move it" "$BEFORE" "$(sum)"

OUT="$("$SCRIPT" --repo "$D" --dir nosuchdir 2>&1)"; RC=$?
if [ "$RC" = 2 ]; then pass "a missing directory exits 2"; else fail "a missing directory exits 2" "got $RC"; fi

BEFORE_RC=0
OUT="$(timeout 10 "$SCRIPT" --dir 2>&1)"; BEFORE_RC=$?
if [ "$BEFORE_RC" = 2 ]; then pass "missing flag value: exit 2"; else fail "missing flag value: exit 2" "got $BEFORE_RC"; fi

rm -rf "$D"

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
