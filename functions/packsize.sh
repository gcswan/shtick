# @name: packsize
# @description: Estimate compressed size, uncompressed text size, and token count for a directory
# @usage: packsize [directory]

packsize() {
  local dir="${1:-.}"
  local excludes=(
    .git node_modules .next dist build .cache
    __pycache__ .venv venv .terraform vendor
    coverage .turbo
    lazy-lock.json package-lock.json yarn.lock pnpm-lock.yaml
  )

  local tar_excludes=()
  local find_excludes=()
  for e in "${excludes[@]}"; do
    tar_excludes+=(--exclude="$e")
    find_excludes+=(-not -path "*/${e}/*" -not -name "$e")
  done

  echo "Compressed: $(tar czf - -C "$dir" "${tar_excludes[@]}" --exclude='*.pyc' . | wc -c | awk '{printf "%.1fKB", $1/1024}')"
  echo "Uncompressed text: $(find "$dir" "${find_excludes[@]}" -not -name '*.pyc' -type f -exec cat {} + 2>/dev/null | wc -c | awk '{printf "%.1fKB", $1/1024}')"
  echo "Est. tokens: $(find "$dir" "${find_excludes[@]}" -not -name '*.pyc' -type f -exec cat {} + 2>/dev/null | wc -c | awk '{printf "%.0fk", $1/4/1000}')"
}
alias pz='packsize'
