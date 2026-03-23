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
  local cmd="${1:-list}"

  case "$cmd" in
    list)
      echo "Available shtick functions:"
      echo ""
      local enabled_names=()
      if [[ -f "$_shtick_conf" ]]; then
        while IFS= read -r line || [[ -n "$line" ]]; do
          [[ -z "$line" || "$line" == \#* ]] && continue
          enabled_names+=("$line")
        done < "$_shtick_conf"
      fi
      for f in "${_shtick_dir}/functions/"**/*.sh; do
        [[ -f "$f" ]] || continue
        local name desc platform marker
        name=$(grep -m1 '^# @name:' "$f" | sed 's/# @name:[[:space:]]*//')
        desc=$(grep -m1 '^# @description:' "$f" | sed 's/# @description:[[:space:]]*//')
        platform=$(grep -m1 '^# @platform:' "$f" | sed 's/# @platform:[[:space:]]*//')
        [[ -z "$name" ]] && continue
        marker="[ ]"
        for n in "${enabled_names[@]}"; do
          if [[ "$n" == "$name" ]]; then
            marker="[*]"
            break
          fi
        done
        if [[ -n "$platform" ]]; then
          printf "  %s %-16s %s [%s]\n" "$marker" "$name" "$desc" "$platform"
        else
          printf "  %s %-16s %s\n" "$marker" "$name" "$desc"
        fi
      done
      echo ""
      echo "  [*] enabled    [ ] disabled"
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
      grep '^# @' "${_found[1]}"
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
      echo "Usage: shtick <command> [args]"
      echo ""
      echo "Commands:"
      echo "  list              list all functions, marking enabled ones"
      echo "  enable <name>     enable a function"
      echo "  disable <name>    disable a function"
      echo "  help <name>       show header for a function"
      echo "  update            git pull the shtick repo"
      echo "  reload            re-source loader.sh"
      ;;
  esac
}
