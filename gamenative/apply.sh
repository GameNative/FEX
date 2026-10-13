#!/bin/sh
# Apply the GameNative patch series to the FEX checkout in the current directory.
# usage: apply.sh <gamenative dir> [extra git-am options, e.g. --3way]
set -eu
dir=$1
shift
grep -v -e '^#' -e '^$' "$dir/series" | while read -r p; do
  echo "Applying $p"
  git am --quiet --whitespace=nowarn "$@" "$dir/patches/$p"
done
