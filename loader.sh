# shtick loader — source this from .zshrc

_shtick_dir="${0:A:h}"  # zsh-native: absolute path of this file's directory
_shtick_conf="${HOME}/.config/shtick/enabled.conf"

# Source enabled functions
if [[ -f "$_shtick_conf" ]]; then
  while IFS= read -r _shtick_name || [[ -n "$_shtick_name" ]]; do
    [[ -z "$_shtick_name" || "$_shtick_name" == \#* ]] && continue
    local -a _shtick_file
    _shtick_file=( "${_shtick_dir}/functions"/**/"${_shtick_name}.sh"(N) )
    if [[ ${#_shtick_file} -gt 0 ]]; then
      # shellcheck disable=SC1090
      source "${_shtick_file[1]}"
    fi
  done < "$_shtick_conf"
fi
unset _shtick_name _shtick_file

# shtick discovery command
shtick() {
  local cmd="${1:-usage}"

  case "$cmd" in
    list)
      local enabled_names=()
      if [[ -f "$_shtick_conf" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
          [[ -z "$line" || "$line" == \#* ]] && continue
          enabled_names+=("$line")
        done < "$_shtick_conf"
      fi

      local entries=() name desc platform marker enabled_count=0 total_count=0
      for f in "${_shtick_dir}/functions/"**/*.sh; do
        [[ -f "$f" ]] || continue
        name=$(grep -m1 '^# @name:' "$f" | sed 's/# @name:[[:space:]]*//')
        desc=$(grep -m1 '^# @description:' "$f" | sed 's/# @description:[[:space:]]*//')
        platform=$(grep -m1 '^# @platform:' "$f" | sed 's/# @platform:[[:space:]]*//')
        [[ -z "$name" ]] && continue
        total_count=$((total_count + 1))
        marker=" "
        for n in "${enabled_names[@]}"; do
          if [[ "$n" == "$name" ]]; then
            marker="*"
            enabled_count=$((enabled_count + 1))
            break
          fi
        done
        local suffix=""
        [[ -n "$platform" ]] && suffix=" \033[2m($platform)\033[0m"
        entries+=("$(printf "  \033[2m[\033[0m\033[1m%s\033[0m\033[2m]\033[0m  \033[36m%-14s\033[0m %s%b" "$marker" "$name" "$desc" "$suffix")")
      done

      echo ""
      printf "  \033[1mshtick\033[0m — shell functions manager\n"
      printf "  \033[2m%d enabled, %d available\033[0m\n" "$enabled_count" "$total_count"
      echo ""
      for entry in "${entries[@]}"; do
        printf "%b\n" "$entry"
      done
      echo ""
      printf "  \033[2m[*] enabled  [ ] disabled  •  shtick enable/disable <name>\033[0m\n"
      echo ""
      ;;

    enable)
      local name="${2:?Usage: shtick enable <name>}"
      if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "shtick: invalid function name '${name}'" >&2
        return 1
      fi
      local -a _found
      _found=( "${_shtick_dir}/functions"/**/"${name}.sh"(N) )
      if [[ ${#_found} -eq 0 ]]; then
        echo "shtick: no function named '${name}'" >&2
        return 1
      fi
      local file="${_found[1]}"
      mkdir -p "$(dirname "$_shtick_conf")"
      touch "$_shtick_conf"
      if grep -qx "$name" "$_shtick_conf" 2>/dev/null; then
        echo "shtick: '${name}' is already enabled"
      else
        echo "$name" >> "$_shtick_conf"
        # shellcheck disable=SC1090
        source "$file"
        echo "shtick: enabled '${name}' (active in current shell)"
      fi
      ;;

    disable)
      local name="${2:?Usage: shtick disable <name>}"
      if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "shtick: invalid function name '${name}'" >&2
        return 1
      fi
      if [[ ! -f "$_shtick_conf" ]] || ! grep -qx "$name" "$_shtick_conf" 2>/dev/null; then
        echo "shtick: '${name}' is not enabled"
        return 1
      fi
      # Portable in-place delete (bash 3.2 / macOS sed compatible)
      local tmp
      tmp=$(mktemp)
      grep -vx "$name" "$_shtick_conf" > "$tmp" && mv "$tmp" "$_shtick_conf"
      echo "shtick: disabled '${name}' (will unload on next shell start)"
      ;;

    help)
      local name="${2:?Usage: shtick help <name>}"
      if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "shtick: invalid function name '${name}'" >&2
        return 1
      fi
      local -a _found
      _found=( "${_shtick_dir}/functions"/**/"${name}.sh"(N) )
      if [[ ${#_found} -eq 0 ]]; then
        echo "shtick: no function named '${name}'" >&2
        return 1
      fi
      echo ""
      while IFS= read -r line; do
        local key val
        key="${line#\# @}"
        key="${key%%:*}"
        val="${line#*: }"
        printf "  \033[2m%-14s\033[0m %s\n" "$key" "$val"
      done < <(grep '^# @' "${_found[1]}")
      echo ""
      ;;

    update)
      git -C "$_shtick_dir" pull
      ;;

    reload)
      # shellcheck disable=SC1090
      source "${_shtick_dir}/loader.sh"
      echo "shtick: reloaded"
      ;;

    *)
      echo ""
      printf "  \033[1mUsage:\033[0m shtick <command> [args]\n"
      echo ""
      printf "  \033[1mCommands:\033[0m\n"
      printf "    \033[36mlist\033[0m              list all functions\n"
      printf "    \033[36menable\033[0m  <name>    enable a function\n"
      printf "    \033[36mdisable\033[0m <name>    disable a function\n"
      printf "    \033[36mhelp\033[0m    <name>    show function details\n"
      printf "    \033[36mupdate\033[0m            git pull the shtick repo\n"
      printf "    \033[36mreload\033[0m            re-source loader.sh\n"
      echo ""
      ;;
  esac
}
