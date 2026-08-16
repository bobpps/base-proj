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
SKIP=0

pass() { PASS=$((PASS + 1)); printf '  ok    %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL  %s\n          %s\n' "$1" "${2-}"; }
# A check that did not run is its own outcome, per `docs/engineering/evidence.md`. Counting it as a
# pass would report a configuration as verified that nothing looked at, and that is the one of the
# four outcomes that always gets quietly dropped.
skip() { SKIP=$((SKIP + 1)); printf '  skip  %s\n          %s\n' "$1" "${2-}"; }

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
  # Every directory containing a SKILL.md, at any depth, pruning what the generator prunes. The
  # depth and the prune list are copied from `findSkillDirs` in copy-skills-to-agents.mjs on
  # purpose: a shallower walk here would call a skill the generator copies one this test never saw.
  local base="$1"
  [ -d "$ROOT/$base" ] || return 0
  find "$ROOT/$base" \
       -type d \( -name node_modules -o -name .git -o -name dist -o -name build -o -name coverage \) -prune \
       -o -type f -name SKILL.md -printf '%h\n' | LC_ALL=C sort
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
#
# The whole section is conditional, because a repository with the Codex contour turned off has no
# generated tree to check: `init-project` deletes `.codex/` and `.agents/` together. Running the
# comparison anyway would derive every `.claude` skill as expected and report all of them absent,
# failing a repository that was initialized exactly as the interview prescribes.
GENERATOR="$ROOT/scripts/copy-skills-to-agents.mjs"

if [ ! -d "$ROOT/.agents/skills" ] && [ ! -d "$ROOT/.codex/skills" ]; then
  skip "the generated tree matches its sources" \
       "no .agents/skills and no .codex/skills — the Codex contour is off in this project"
elif [ ! -f "$GENERATOR" ]; then
  fail "the generated tree matches its sources" \
       "a generated tree exists but ${GENERATOR#"$ROOT"/} does not, so nothing can say what belongs in it"
else

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

# Skills vendored from a plugin cache or the user's own global directory, when block 5's vendoring
# contour is on. They belong in the generated tree and have no source in this repository, so without
# the generator's own record of them they are indistinguishable from a hand-added directory — and
# labelling them `unexpected` would leave every project that chose that contour with a permanently
# red CI step.
#
# Reading the record rather than the source is deliberate. The sources are one machine's home
# directory; CI has no such home, so a check that looked there would report every vendored skill
# absent instead — failing in the opposite direction and in the place that matters more.
#
# The manifest records contents, not names, and the difference is the whole of its value. A name
# proves the directory is still there; the vendored copy is committed like any other file, so a hand
# edit inside it is exactly as likely as one anywhere else. Recording names alone would have fixed
# round 5's false positive by opening a blind spot, which round 6 duly found.
VENDOR_MARKER="$ROOT/.agents/skills/.vendored"
vendored=""
if [ -f "$VENDOR_MARKER" ]; then
  vendored="$(sed 's/^[0-9a-f]*  //' "$VENDOR_MARKER" | cut -d/ -f1 | LC_ALL=C sort -u | tr '\n' ' ')"

  # sha256 of a file's bytes is the same number whoever computes it, so this is a shared standard
  # rather than a reimplementation of the generator. Prefer coreutils, accept the BSD spelling, and
  # say plainly when neither is here — a content check nobody ran must not read as one that passed.
  if command -v sha256sum >/dev/null 2>&1; then VERIFY="sha256sum -c"
  elif command -v shasum >/dev/null 2>&1;   then VERIFY="shasum -a 256 -c"
  else VERIFY=""
  fi

  if [ -n "$VERIFY" ]; then
    # Results go to stdout as `<path>: OK` or `<path>: FAILED`; the summary warning goes to stderr
    # and is noise here, because every path it summarises is already on stdout.
    bad="$( (cd "$ROOT/.agents/skills" && $VERIFY .vendored 2>/dev/null) \
            | grep -v ': OK$' | sed 's/: FAILED.*//' | LC_ALL=C sort -u | tr '\n' ' ' )"
    [ -z "${bad// /}" ] || drift="$drift (vendored, content differs: ${bad% })"
  else
    skip "vendored skill contents match the manifest" \
         "neither sha256sum nor shasum is installed, so the manifest could not be verified"
  fi

  # The manifest lists what belongs; a file added inside a vendored skill is listed nowhere, so the
  # verification above cannot see it. Compare the file sets in the other direction too.
  listed="$(sed 's/^[0-9a-f]*  //' "$VENDOR_MARKER" | LC_ALL=C sort)"
  for name in $vendored; do
    if [ ! -d "$ROOT/.agents/skills/$name" ]; then
      drift="$drift $name(vendored, absent)"
      continue
    fi
    present="$(cd "$ROOT/.agents/skills" && find "$name" -type f | LC_ALL=C sort)"
    extra="$(comm -13 <(printf '%s\n' "$listed") <(printf '%s\n' "$present") | tr '\n' ' ')"
    [ -z "${extra// /}" ] || drift="$drift $name(vendored, unlisted files: ${extra% })"
  done
fi

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

# A name in the marker that this repository also owns is a contradiction: the repository sources win
# in the generator, so it would never have vendored that name. Report it rather than letting a
# hand-edited marker silence a real finding — the marker is only trustworthy as the generator's own
# statement about what it did.
for name in $vendored; do
  case " $expected " in *" $name "*) drift="$drift $name(vendored, but this repository owns it)" ;; esac
done

# Every entry in the generated root, not every skill in it. The generator clears the whole directory
# and rebuilds it, so anything that is neither an expected skill directory nor a recorded vendored
# one is drift — and a scan that looked only for directories holding a SKILL.md could not see it. A
# stray file added under `.agents/skills/` passed this check until round 4 of the review said so.
while IFS= read -r entry; do
  [ -n "$entry" ] || continue
  name="$(basename "$entry")"
  [ "$name" = ".vendored" ] && continue          # the generator's own record, not a skill
  if [ ! -d "$entry" ]; then
    drift="$drift $name(stray file)"
  else
    case " $expected $vendored " in *" $name "*) ;; *) drift="$drift $name(unexpected)" ;; esac
  fi
done <<< "$(find "$ROOT/.agents/skills" -mindepth 1 -maxdepth 1 2>/dev/null | LC_ALL=C sort)"

if [ -z "$drift" ]; then
  pass ".agents/skills matches what the generator would write"
else
  fail ".agents/skills matches what the generator would write" "run scripts/copy-skills-to-agents.mjs —$drift"
fi

fi

echo
if [ "$SKIP" -gt 0 ]; then
  echo "  $PASS passed, $FAIL failed, $SKIP skipped"
else
  echo "  $PASS passed, $FAIL failed"
fi
[ "$FAIL" -eq 0 ]
