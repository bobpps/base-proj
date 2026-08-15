#!/usr/bin/env bash
#
# Asserts the properties `docs/engineering/writing-skills.md` and `CLAUDE.md` state about the skills
# on disk — the ones a reader can check mechanically and a reviewer cannot check reliably by eye.
#
# Each check here replaces a sentence that was already written down and already broken:
#
#   - Both task-pipeline editions invoked a `retrospective` skill at phase 12 while `CLAUDE.md`
#     recorded, in its own table, that no such skill existed. The table said the right thing and
#     nothing compared it to the disk, so the failure was reserved for whoever ran the pipeline.
#   - `writing-skills.md` fixes a hard ceiling of 5000 words on a SKILL.md body, and gives the
#     reason: past the ceiling the file is not thorough, it is a skill whose references were never
#     split out.
#   - It also says a resource the body never mentions is a resource nothing will read. A file
#     nobody reads costs nothing to add and is invisible afterwards, which is why it accumulates.
#   - `AGENTS.md` says `.agents/skills/` is generated and must not be edited by hand. A hand edit
#     there survives until the next regeneration silently reverts it.
#
# No arguments. The repository is the one this script lives in.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n          %s\n' "$1" "${2-}"; }

# The body is everything after the leading frontmatter block. The frontmatter is metadata that is
# always loaded and is budgeted separately; counting it against the body's ceiling would charge the
# description twice.
body_words() {
  awk 'NR==1 && $0=="---" { fm=1; next }
       fm==1 && $0=="---" { fm=0; body=1; next }
       fm==1 { next }
       { print }' "$1" | wc -w
}

frontmatter_name() {
  awk 'NR==1 && $0=="---" { fm=1; next }
       fm==1 && $0=="---" { exit }
       fm==1 && /^name:[[:space:]]*/ { sub(/^name:[[:space:]]*/, ""); print; exit }' "$1"
}

is_superseded() {
  awk 'NR==1 && $0=="---" { fm=1; next }
       fm==1 && $0=="---" { exit }
       fm==1 && /^superseded-by:[[:space:]]*[^[:space:]]/ { found=1; exit }
       END { exit found ? 0 : 1 }' "$1"
}

skill_dirs() {
  # Every directory directly containing a SKILL.md, under the source trees this repository owns.
  local base
  for base in "$1"; do
    [ -d "$ROOT/$base" ] || continue
    find "$ROOT/$base" -mindepth 1 -maxdepth 2 -name SKILL.md -printf '%h\n' | LC_ALL=C sort
  done
}

echo "skills"

# ---------------------------------------------------------------------------- name matches directory

bad_names=""
counted=0
for tree in .claude/skills .codex/skills .agents/skills; do
  while read -r dir; do
    [ -n "$dir" ] || continue
    counted=$((counted + 1))
    declared="$(frontmatter_name "$dir/SKILL.md")"
    [ "$declared" = "$(basename "$dir")" ] || bad_names="$bad_names ${dir#"$ROOT"/}(name:${declared:-<none>})"
  done <<< "$(skill_dirs "$tree")"
done

if [ "$counted" -gt 0 ]; then
  pass "skills were found to check ($counted directories)"
else
  fail "skills were found to check" "found none; the discovery is broken"
fi

if [ -z "$bad_names" ]; then
  pass "every SKILL.md declares the name of its own directory"
else
  fail "every SKILL.md declares the name of its own directory" "mismatched:$bad_names"
fi

# ---------------------------------------------------------------------------- the body ceiling

CEILING=5000
oversize=""
for tree in .claude/skills .codex/skills; do
  while read -r dir; do
    [ -n "$dir" ] || continue
    words="$(body_words "$dir/SKILL.md")"
    [ "$words" -le "$CEILING" ] || oversize="$oversize ${dir#"$ROOT"/}($words)"
  done <<< "$(skill_dirs "$tree")"
done

if [ -z "$oversize" ]; then
  pass "no SKILL.md body exceeds the $CEILING-word ceiling"
else
  fail "no SKILL.md body exceeds the $CEILING-word ceiling" "over:$oversize"
fi

# ---------------------------------------------------------------------------- references are reachable

unmentioned=""
refs_checked=0
for tree in .claude/skills .codex/skills; do
  while read -r dir; do
    [ -n "$dir" ] || continue
    [ -d "$dir/references" ] || continue
    for ref in "$dir"/references/*; do
      [ -f "$ref" ] || continue
      refs_checked=$((refs_checked + 1))
      # Named anywhere in the body — `references/x.md` or a bare `x.md` both count as a pointer.
      grep -qF "$(basename "$ref")" "$dir/SKILL.md" || unmentioned="$unmentioned ${ref#"$ROOT"/}"
    done
  done <<< "$(skill_dirs "$tree")"
done

if [ -z "$unmentioned" ]; then
  pass "every reference file is named by its own SKILL.md ($refs_checked checked)"
else
  fail "every reference file is named by its own SKILL.md" "never mentioned:$unmentioned"
fi

# ---------------------------------------------------------------------------- the table matches the disk

TABLE="$ROOT/CLAUDE.md"
listed="$(awk '/^## Which skill for which request/ { inside=1; next }
               inside && /^## / { exit }
               inside && /^\| .* \| `[a-z][a-z0-9-]*` \|/ {
                 match($0, /`[a-z][a-z0-9-]*`/)
                 print substr($0, RSTART + 1, RLENGTH - 2)
               }' "$TABLE" | LC_ALL=C sort -u)"

# Live skills only. `writing-skills.md` says a replaced skill keeps its directory and gains a
# `superseded-by:` marker, and a retired skill has no business in a table headed "which skill for
# which request" — so counting the directory here would fail a repository that retired one exactly
# as the doctrine tells it to.
on_disk="$(skill_dirs .claude/skills | while read -r d; do
  [ -n "$d" ] || continue
  is_superseded "$d/SKILL.md" && continue
  basename "$d"
done | LC_ALL=C sort -u)"

if [ -n "$listed" ]; then
  pass "the skill table lists skills ($(echo "$listed" | wc -l))"
else
  fail "the skill table lists skills" "found none in CLAUDE.md; the extraction is broken"
fi

missing_dir="$(comm -23 <(echo "$listed") <(echo "$on_disk") | tr '\n' ' ')"
missing_row="$(comm -13 <(echo "$listed") <(echo "$on_disk") | tr '\n' ' ')"

if [ -z "${missing_dir// /}" ]; then
  pass "every skill in the table is present and live under .claude/skills"
else
  fail "every skill in the table is present and live under .claude/skills" \
       "listed but absent or retired: $missing_dir"
fi

if [ -z "${missing_row// /}" ]; then
  pass "every live skill under .claude/skills has a row in the table"
else
  fail "every live skill under .claude/skills has a row in the table" "on disk but unlisted: $missing_row"
fi

# ---------------------------------------------------------------------------- .agents is generated

# The generator copies whole directories: `.codex` wins where both exist, `.claude` otherwise, and a
# skill is skipped when it carries `superseded-by:` or appears in the generator's IGNORE map. So
# `.agents` is comparable byte for byte, and any difference is either a hand edit or a source that
# moved on without regeneration.
#
# IGNORE is read out of the generator rather than restated here. Restating it would make this check
# disagree with the tool it is checking the moment somebody adds an entry — it would report the
# skill as missing from `.agents/` while the generator was correctly leaving it out.
GENERATOR="$ROOT/scripts/copy-skills-to-agents.mjs"
ignore_block="$(awk '/^const IGNORE = \{/ { inside=1; found=1; next }
                     inside && /^\};/    { inside=0; next }
                     inside              { print }
                     END                 { exit found ? 0 : 1 }' "$GENERATOR")"
if [ $? -eq 0 ]; then
  pass "the generator's IGNORE map is readable"
else
  # Loud rather than empty. An unreadable map silently becomes "nothing is ignored", which is the
  # same answer as a correctly empty map and would hide a renamed constant forever.
  fail "the generator's IGNORE map is readable" "no 'const IGNORE = {' block in ${GENERATOR#"$ROOT"/}"
fi

ignored="$(printf '%s\n' "$ignore_block" \
           | sed 's://.*::' \
           | grep -oE "^[[:space:]]*('[^']+'|\"[^\"]+\")" \
           | tr -d " '\"" )"

drift=""
expected=""
for tree in .codex/skills .claude/skills; do
  while read -r dir; do
    [ -n "$dir" ] || continue
    name="$(basename "$dir")"
    case " $expected " in *" $name "*) continue ;; esac   # a higher-priority source already claimed it
    case " $(echo $ignored) " in *" $name "*) continue ;; esac
    is_superseded "$dir/SKILL.md" && continue
    expected="$expected $name"
    if [ ! -d "$ROOT/.agents/skills/$name" ]; then
      drift="$drift $name(absent)"
    elif ! diff -rq "$dir" "$ROOT/.agents/skills/$name" >/dev/null 2>&1; then
      drift="$drift $name(differs)"
    fi
  done <<< "$(skill_dirs "$tree")"
done

while read -r dir; do
  [ -n "$dir" ] || continue
  name="$(basename "$dir")"
  case " $expected " in *" $name "*) ;; *) drift="$drift $name(unexpected)" ;; esac
done <<< "$(skill_dirs .agents/skills)"

if [ -z "$drift" ]; then
  pass ".agents/skills matches what the generator would write"
else
  fail ".agents/skills matches what the generator would write" "run scripts/copy-skills-to-agents.mjs —$drift"
fi

echo
echo "  $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
