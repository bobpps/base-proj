#!/usr/bin/env bash
#
# Lists the template placeholders still standing in the files a configuration run is meant to fill.
#
# `init-project` runs this to decide whether a run is finished, and reports whatever it prints.
#
# It takes an **allowlist**, not an exclusion list, and that is the whole design. The obvious
# version — grep the tree for `{{`, minus some exceptions — was written twice and was incomplete
# both times: first it counted the skills and the specification, which describe placeholders in
# order to refuse them; then, with those excluded, it still counted TEMPLATE.md and the workflow's
# own header comment. An exclusion list fails in the direction that makes the check unpassable, and
# an unpassable check is not ignored so much as satisfied dishonestly — by editing whatever is
# easiest to edit, which in a workflow means its own `${{ }}` expressions.
#
# Inverting it removes the whole class. The set of files that must end up free of placeholders is
# exactly the set the interview writes, and that set is enumerated in the skill's own writing map
# rather than inferred here. Every other file in the repository may contain `{{` forever, and
# nothing about a new document can make this check wrong.
#
#   ./placeholders.sh [--repo <dir>] [path ...]
#
# Paths default to the files `init-project` fills. Missing ones are skipped rather than reported:
# a project with no `.mcp.json` has not left a placeholder in it.
#
# Exit 0 when nothing is unresolved — `{{TODO}}` markers may remain, since those are answers the
# human deferred and the final report names each one. Exit 1 when an unresolved placeholder is
# left. Exit 2 on bad arguments.

set -uo pipefail

REPO="."
PATHS=()
# A flag that takes a value proves the value is there before consuming two arguments. `shift 2`
# with one argument left fails, and what happens then depends only on which `set` line this script
# happens to carry: with `set -e` it exits 1 and says nothing, and without it the loop never
# advances and the script hangs. Both were observed. Neither is the documented status 2.
need_value() {
  [ $# -ge 2 ] || { echo "$1 needs a value" >&2; exit 2; }
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) need_value "$@"; REPO="$2"; shift 2 ;;
    -h|--help) echo "usage: placeholders.sh [--repo <dir>] [path ...]" >&2; exit 2 ;;
    -*) echo "unknown argument: $1" >&2; exit 2 ;;
    *) PATHS+=("$1"); shift ;;
  esac
done

[ -d "$REPO" ] || { echo "no such directory: $REPO" >&2; exit 2; }

if [ "${#PATHS[@]}" -eq 0 ]; then
  PATHS=(
    AGENTS.md
    CLAUDE.md
    README.md
    .github/workflows/ci.yml
    .claude/settings.json
    .mcp.json
    package.json
    global.json
    .nvmrc
  )
  # .NET puts its manifests wherever the solution puts them, so they are found rather than named.
  # A generated `*.csproj` carrying an unanswered value would otherwise pass the scan and be
  # reported as a finished run.
  while IFS= read -r found; do
    PATHS+=("${found#./}")
  done < <(
    cd "$REPO" && find . -name '*.csproj' \
      -not -path './.git/*' -not -path './node_modules/*' 2>/dev/null
  )
fi

# Removes each `${{ … }}` expression, shortest match first.
#
# The obvious `sed 's/\${{[^}]*}}//g'` stops at the first `}`, so it fails on an expression whose
# body contains one — `${{ format('{0}', github.sha) }}` is valid and common. Making the pattern
# greedy is worse: it would swallow a real placeholder sitting between two expressions on one line.
# So walk the line, and for each opening take everything up to the first `}}` that follows it.
strip_expressions() {
  local s="$1" out="" head rest
  while [ "${s#*\$\{\{}" != "$s" ]; do
    head="${s%%\$\{\{*}"
    rest="${s#*\$\{\{}"
    out="$out$head"
    if [ "${rest#*\}\}}" != "$rest" ]; then
      s="${rest#*\}\}}"
    else
      # An opening with no closing: keep the remainder so nothing is silently discarded.
      s="$rest"
      break
    fi
  done
  printf '%s' "$out$s"
}

todo=0
unresolved=0

for rel in "${PATHS[@]}"; do
  f="$REPO/$rel"
  [ -f "$f" ] || continue

  n=0
  # `|| [ -n "$line" ]` catches a file whose last line has no trailing newline. Without it `read`
  # returns non-zero on that line and the loop drops it, so a file ending in an unfilled value is
  # reported as clean — which an editor produces without anyone deciding to.
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))

    # `${{ … }}` belongs to GitHub Actions and to everything else that borrowed the syntax. It is
    # not an unfilled value, and a run that "cleared" it would be editing the workflow's logic.
    stripped="$(strip_expressions "$line")"

    # Count the deferred answers, then take them out of the line. Doing this in one step rather
    # than branching on the line as a whole is what stops `{{TODO}} and {{PROJECT_NAME}}` being
    # filed as a deferred answer and reported as a finished run.
    while case "$stripped" in *'{{TODO}}'*) true ;; *) false ;; esac; do
      todo=$((todo + 1))
      stripped="${stripped/'{{TODO}}'/}"
      printf 'todo       %s:%s:%s\n' "$rel" "$n" "$line"
    done

    case "$stripped" in
      *'{{'*)
        unresolved=$((unresolved + 1))
        printf 'unresolved %s:%s:%s\n' "$rel" "$n" "$line"
        ;;
    esac
  done < "$f"
done

echo "todo=$todo"
echo "unresolved=$unresolved"
[ "$unresolved" -eq 0 ]
