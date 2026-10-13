#!/bin/sh
# Rebase the series onto a new upstream ref and rewrite the patch files.
#
#   rebase.sh <upstream ref>          clone upstream at <ref>, apply the series with 3-way merge,
#                                     regenerate patches/ and series on success
#   rebase.sh --regen <checkout>      after fixing a conflict by hand in <checkout>
#                                     (git am --continue, or git am --skip to drop a merged patch),
#                                     regenerate patches/ and series from its commits
#
# Each regenerated patch keeps its From/Subject/body, so authorship and the upstream links survive.
# When a patch is skipped (already upstream), delete its row in README.md and bump SERIES_VERSION.
set -eu
dir=$(cd "$(dirname "$0")" && pwd)

regen() {
  repo=$1
  base=$(cat "$repo/.gn-base")
  cd "$repo"
  n=$(git rev-list --count "$base..HEAD")
  rm -f "$dir"/patches/*.patch
  : > "$dir/series"
  i=0
  git rev-list --reverse "$base..HEAD" | while read -r c; do
    i=$((i + 1))
    slug=$(git log -1 --format=%s "$c" | sed -e 's/^\[PATCH[^]]*\] *//' -e 's/[^A-Za-z0-9]\{1,\}/-/g' -e 's/^-//' -e 's/-$//' | tr 'A-Z' 'a-z' | cut -c1-48)
    name=$(printf '%04d-%s.patch' "$i" "$slug")
    git format-patch --quiet --no-signature --zero-commit --no-numbered --stdout -1 "$c" > "$dir/patches/$name"
    echo "$name" >> "$dir/series"
    echo "wrote $name"
  done
  echo "$n patches regenerated on $(git describe --tags --always "$base")"
}

if [ "${1:-}" = "--regen" ]; then
  regen "$2"
  exit 0
fi

ref=${1:?usage: rebase.sh <upstream ref> | --regen <checkout>}
work=$(mktemp -d "${TMPDIR:-/tmp}/fex-rebase.XXXXXX")
git clone --quiet --filter=blob:none https://github.com/FEX-Emu/FEX.git "$work/fex"
cd "$work/fex"
git checkout --quiet "$ref"
git config user.name gamenative
git config user.email ci@gamenative.app
git rev-parse HEAD > .gn-base
if "$dir/apply.sh" "$dir" --3way; then
  regen "$work/fex"
else
  echo
  echo "Conflict. Fix it in $work/fex, then:"
  echo "  git am --continue        (or: git am --skip  if upstream already has the patch)"
  echo "  $0 --regen $work/fex"
  exit 1
fi
