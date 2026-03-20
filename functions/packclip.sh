# @name: packclip
# @description: Package a directory into a .tar.gz and copy it to the macOS clipboard
# @usage: packclip <directory>

packclip() {
  local dir="${1:?Usage: packclip <directory>}"
  local name=$(basename "$(realpath "$dir")")
  local tmp="/tmp/${name}-$(date +%s).tar.gz"
  local excludes=(
    .git node_modules .next dist build .cache
    __pycache__ .venv venv .terraform vendor
    coverage .turbo
    lazy-lock.json package-lock.json yarn.lock pnpm-lock.yaml
  )

  local tar_excludes=()
  for e in "${excludes[@]}"; do
    tar_excludes+=(--exclude="$e")
  done

  tar czf "$tmp" -C "$dir" "${tar_excludes[@]}" --exclude='*.pyc' . \
    && osascript -e "set the clipboard to (POSIX file \"$tmp\")" \
    && echo "Copied $tmp to clipboard"
}
alias pc='packclip'
