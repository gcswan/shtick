# @name: packsize
# @description: Estimate compressed size, uncompressed text size, and token count for a directory
# @usage: packsize [directory]

source "${0:A:h}/_excludes.sh"

packsize() {
  local dir="${1:-.}"

  local tar_excludes=()
  local find_excludes=()
  for e in "${SHTICK_EXCLUDES[@]}"; do
    tar_excludes+=(--exclude="$e")
    find_excludes+=(-not -path "*/${e}/*" -not -name "$e")
  done

  echo "Compressed: $(tar czf - "${tar_excludes[@]}" --exclude='*.pyc' -C "$dir" . | wc -c | awk '{printf "%.1fKB", $1/1024}')"
  echo "Uncompressed text: $(find "$dir" "${find_excludes[@]}" -not -name '*.pyc' -type f -exec cat {} + 2>/dev/null | wc -c | awk '{printf "%.1fKB", $1/1024}')"
  echo "Est. tokens: $(find "$dir" "${find_excludes[@]}" -not -name '*.pyc' -type f -exec cat {} + 2>/dev/null | wc -c | awk '{printf "%.0fk", $1/4/1000}')"
}
