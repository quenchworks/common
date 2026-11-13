#!/usr/bin/env bash
# Renders real consumer charts against this working tree's quench-common, so a broken helper
# fails here instead of after an immutable version is published (helm lint renders nothing for a
# library chart). The consumers are the charts that call the most helpers.
# Usage: scripts/render-consumers.sh <path to a quenchworks/charts checkout> [chart...]
set -euo pipefail
charts="${1:?usage: render-consumers.sh <charts checkout> [chart...]}"
shift
[ $# -gt 0 ] || set -- dex vault xyops quickwit uptime-kuma
lib="$(cd "$(dirname "$0")/../quench-common" && pwd)"
ver="$(awk '/^version:/{print $2; exit}' "$lib/Chart.yaml")"
work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT
# helm dependency build reads the user's repo list; the file:// dependency needs none
printf 'repositories: []\n' > "$work/repos.yaml"
export HELM_REPOSITORY_CONFIG="$work/repos.yaml"

for c in "$@"; do
  cp -r "$charts/quench/$c" "$work/$c"
  rm -rf -- "$work/$c/charts" "$work/$c/Chart.lock"
  # point the quench-common dependency at this tree, whatever version the chart pins
  awk -v ver="$ver" -v repo="file://$lib" '
    /- name: quench-common/ { dep = 1 }
    dep && /^ *version:/    { sub(/version:.*/, "version: " ver) }
    dep && /^ *repository:/ { sub(/repository:.*/, "repository: " repo); dep = 0 }
    { print }' "$charts/quench/$c/Chart.yaml" > "$work/$c/Chart.yaml"
  helm dependency build "$work/$c" >/dev/null
  values=()
  [ -f "$work/$c/ci/default-values.yaml" ] && values=(-f "$work/$c/ci/default-values.yaml")
  helm template rtest "$work/$c" "${values[@]}" >/dev/null
  echo "ok $c (quench-common $ver)"
done
