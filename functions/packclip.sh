# @name: packclip
# @description: Package a directory into a .tar.gz and copy it to the macOS clipboard
# @usage: packclip <directory>
# @platform: macOS

source "${0:A:h}/_excludes.sh"

packclip() {
  local dir="${1:?Usage: packclip <directory>}"
  local name=$(basename "$(realpath "$dir")")
  local tmp="/tmp/${name}-$(date +%s).tar.gz"

  local tar_excludes=()
  for e in "${SHTICK_EXCLUDES[@]}"; do
    tar_excludes+=(--exclude="$e")
  done

  tar czf "$tmp" "${tar_excludes[@]}" --exclude='*.pyc' -C "$dir" . \
    && osascript -e "set the clipboard to (POSIX file \"$tmp\")" \
    && echo "Copied $tmp to clipboard"
}
