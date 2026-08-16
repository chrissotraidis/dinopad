#!/usr/bin/env bash
# report-size.sh - report DinoPad repository and workspace sizes.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1

human() {
  awk -v n="$1" 'BEGIN {
    if (n < 1024)      { printf "%d B", n; exit }
    if (n < 1048576)   { printf "%.1f KiB", n / 1024; exit }
    if (n < 1073741824){ printf "%.1f MiB", n / 1048576; exit }
    printf "%.1f GiB", n / 1073741824
  }'
}

total=0
count=0
largest=()
while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  s="$(wc -c < "$f")"
  total=$((total + s))
  count=$((count + 1))
  largest+=("$s $f")
done < <(git ls-files -z)

echo "== DinoPad repository size report =="
echo "Tracked files: $count"
echo "Tracked size:  $(human "$total")"
echo ""
echo "Largest tracked files (top 10):"
printf '%s\n' "${largest[@]}" | sort -rn | head -10 | while read -r s f; do
  printf '  %10s  %s\n' "$(human "$s")" "$f"
done
echo ""
echo "Ignored workspaces (size on disk):"
du -sh ref generated private-fixtures logs build-macos build-ios-simulator build-ios-device 2>/dev/null || true
echo ""
echo "Disk free:"
df -h .
