#!/usr/bin/env bash
#
# Lists the template placeholders still standing in this repository.
#
# `init-project` runs this to decide whether a configuration run is finished, and reports whatever
# it prints. It exists as a script because the obvious one-liner — grep for `{{` — is wrong in two
# ways that both look like success:
#
#   - `${{ github.sha }}` in a GitHub workflow is a valid expression, not an unfilled placeholder.
#     An agent clearing the check by hand would edit the workflow's own logic to satisfy a grep.
#   - The skills and the specification *describe* placeholders in order to refuse them. Their text
#     is supposed to contain `{{PLACEHOLDER}}` forever, and a check that counts it can never pass.
#
#   ./placeholders.sh [--repo <dir>]
#
# Exit 0 when nothing is unresolved — `{{TODO}}` markers may remain, since those are answers the
# human deferred and the final report names each one. Exit 1 when an unresolved placeholder is
# left. Exit 2 on bad arguments.

set -uo pipefail

REPO="."
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) REPO="${2-}"; shift 2 ;;
    -h|--help) echo "usage: placeholders.sh [--repo <dir>]" >&2; exit 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -d "$REPO" ] || { echo "no such directory: $REPO" >&2; exit 2; }

# Directories whose whole job is to talk about placeholders. Excluded by path rather than by
# content, because excluding by content would also hide a real placeholder that happened to sit
# next to an example.
is_documentation_about_placeholders() {
  case "$1" in
    ./.claude/skills/*|./.codex/skills/*|./.agents/skills/*|./docs/specs/*) return 0 ;;
    *) return 1 ;;
  esac
}

todo=0
unresolved=0

while IFS= read -r hit; do
  path="${hit%%:*}"
  is_documentation_about_placeholders "$path" && continue

  # `${{ … }}` belongs to GitHub Actions and to every other tool that borrowed the syntax. Strip
  # those occurrences from the line before deciding whether anything is left.
  stripped="$(printf '%s' "$hit" | sed 's/\${{[^}]*}}//g')"
  case "$stripped" in
    *'{{'*) ;;
    *) continue ;;
  esac

  case "$stripped" in
    *'{{TODO}}'*) todo=$((todo + 1));       printf 'todo       %s\n' "$hit" ;;
    *)            unresolved=$((unresolved + 1)); printf 'unresolved %s\n' "$hit" ;;
  esac
done < <(
  cd "$REPO" && grep -rn '{{' \
    --include='*.md' --include='*.yml' --include='*.yaml' --include='*.json' \
    --include='*.template' \
    --exclude-dir=.git --exclude-dir=node_modules . 2>/dev/null
)

echo "todo=$todo"
echo "unresolved=$unresolved"
[ "$unresolved" -eq 0 ]
