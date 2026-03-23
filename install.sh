#!/usr/bin/env bash
# shtick installer

set -e

SHTICK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
SHTICK_CONF="${HOME}/.config/shtick/enabled.conf"
ZSHRC="${HOME}/.zshrc"
LOADER_LINE="source \"${SHTICK_DIR}/loader.sh\""

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_parse_header() {
  local file="$1" field="$2"
  grep -m1 "^# @${field}:" "$file" | sed "s/# @${field}:[[:space:]]*//"
}

_scan_functions() {
  # Populates parallel arrays: FUNC_NAMES, FUNC_DESCS, FUNC_FILES, FUNC_DIRS
  FUNC_NAMES=()
  FUNC_DESCS=()
  FUNC_FILES=()
  FUNC_DIRS=()
  # Root-level files first, then one level of subdirectories
  for f in "${SHTICK_DIR}/functions/"*.sh "${SHTICK_DIR}/functions/"*/*.sh; do
    [[ -f "$f" ]] || continue
    [[ "$(basename "$f")" == _* ]] && continue
    local name desc rel dir
    name=$(_parse_header "$f" "name")
    desc=$(_parse_header "$f" "description")
    if [[ -z "$name" ]]; then
      echo "warning: skipping ${f} (missing @name header)" >&2
      continue
    fi
    rel="${f#${SHTICK_DIR}/functions/}"
    [[ "$rel" == */* ]] && dir="${rel%%/*}" || dir=""
    FUNC_NAMES+=("$name")
    FUNC_DESCS+=("$desc")
    FUNC_FILES+=("$f")
    FUNC_DIRS+=("$dir")
  done
}

_write_conf() {
  # $@: list of names to enable
  mkdir -p "$(dirname "$SHTICK_CONF")"
  printf '%s\n' "$@" > "$SHTICK_CONF"
}

_patch_zshrc() {
  if grep -qF "$LOADER_LINE" "$ZSHRC" 2>/dev/null; then
    return 0
  fi
  echo "" >> "$ZSHRC"
  echo "# shtick" >> "$ZSHRC"
  echo "$LOADER_LINE" >> "$ZSHRC"
  echo "install: added loader to ${ZSHRC}"
}

_read_enabled() {
  ENABLED_NAMES=()
  [[ -f "$SHTICK_CONF" ]] || return 0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    ENABLED_NAMES+=("$line")
  done < "$SHTICK_CONF"
}

_is_enabled() {
  local name="$1"
  for n in "${ENABLED_NAMES[@]}"; do
    [[ "$n" == "$name" ]] && return 0
  done
  return 1
}

_print_function_list() {
  # $1: pass "numbered" to show selection numbers
  local numbered="${1:-}"
  local last_dir="__none__"
  for i in "${!FUNC_NAMES[@]}"; do
    local dir="${FUNC_DIRS[$i]}"
    if [[ "$dir" != "$last_dir" ]]; then
      [[ -n "$dir" ]] && printf "\n  %s\n\n" "${dir^}"
      last_dir="$dir"
    fi
    local marker="[ ]"
    _is_enabled "${FUNC_NAMES[$i]}" && marker="[*]"
    if [[ -n "$numbered" ]]; then
      printf "  %2d) %s %-16s %s\n" "$((i+1))" "$marker" "${FUNC_NAMES[$i]}" "${FUNC_DESCS[$i]}"
    else
      printf "  %s %-16s %s\n" "$marker" "${FUNC_NAMES[$i]}" "${FUNC_DESCS[$i]}"
    fi
  done
}

# ---------------------------------------------------------------------------
# Non-interactive flags
# ---------------------------------------------------------------------------

case "${1:-}" in
  --list)
    _scan_functions
    _read_enabled
    echo "Available shtick functions:"
    echo ""
    _print_function_list
    exit 0
    ;;

  --enable-all)
    _scan_functions
    if [[ ${#FUNC_NAMES[@]} -eq 0 ]]; then
      echo "install: no functions found in ${SHTICK_DIR}/functions/" >&2
      exit 1
    fi
    _write_conf "${FUNC_NAMES[@]}"
    _patch_zshrc
    echo "install: enabled all functions: ${FUNC_NAMES[*]}"
    echo "install: restart your shell or run: source ~/.zshrc"
    exit 0
    ;;

  --enable)
    shift
    if [[ -z "${1:-}" ]]; then
      echo "Usage: install.sh --enable <name>[,<name>...]" >&2
      exit 1
    fi
    IFS=',' read -ra REQUESTED <<< "$1"
    _scan_functions
    TO_ENABLE=()
    for req in "${REQUESTED[@]}"; do
      req="${req// /}"  # trim spaces
      found=0
      for name in "${FUNC_NAMES[@]}"; do
        if [[ "$name" == "$req" ]]; then
          found=1
          break
        fi
      done
      if [[ $found -eq 0 ]]; then
        echo "install: unknown function '${req}'" >&2
        exit 1
      fi
      TO_ENABLE+=("$req")
    done
    _write_conf "${TO_ENABLE[@]}"
    _patch_zshrc
    echo "install: enabled: ${TO_ENABLE[*]}"
    echo "install: restart your shell or run: source ~/.zshrc"
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Interactive mode
# ---------------------------------------------------------------------------

_scan_functions
_read_enabled

if [[ ${#FUNC_NAMES[@]} -eq 0 ]]; then
  echo "install: no functions found in ${SHTICK_DIR}/functions/" >&2
  exit 1
fi

echo ""
echo "  shtick — your bag of sh tricks"
echo ""

if [[ -f "$SHTICK_CONF" ]]; then
  echo "  Existing config found: ${SHTICK_CONF}"
  echo "  Re-running will update your selections."
  echo ""
fi

echo "  Available functions:"
echo ""
_print_function_list numbered

echo ""
echo "  Enter numbers to enable (e.g. 1 2), a range (e.g. 1-3), or 'all'."
echo "  Leave blank to keep current selection (if any)."
echo ""
printf "  > "
read -r SELECTION

# Parse selection
SELECTED_NAMES=()

if [[ -z "$SELECTION" && ${#ENABLED_NAMES[@]} -gt 0 ]]; then
  # Keep current
  SELECTED_NAMES=("${ENABLED_NAMES[@]}")
elif [[ "$SELECTION" == "all" ]]; then
  SELECTED_NAMES=("${FUNC_NAMES[@]}")
else
  # Expand numbers and ranges
  for token in $SELECTION; do
    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      start="${BASH_REMATCH[1]}"
      end="${BASH_REMATCH[2]}"
      for ((n=start; n<=end; n++)); do
        idx=$((n-1))
        if [[ $idx -ge 0 && $idx -lt ${#FUNC_NAMES[@]} ]]; then
          SELECTED_NAMES+=("${FUNC_NAMES[$idx]}")
        else
          echo "install: index ${n} out of range, skipping" >&2
        fi
      done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      idx=$((token-1))
      if [[ $idx -ge 0 && $idx -lt ${#FUNC_NAMES[@]} ]]; then
        SELECTED_NAMES+=("${FUNC_NAMES[$idx]}")
      else
        echo "install: index ${token} out of range, skipping" >&2
      fi
    else
      echo "install: unrecognized token '${token}', skipping" >&2
    fi
  done
fi

if [[ ${#SELECTED_NAMES[@]} -eq 0 ]]; then
  echo ""
  echo "  No functions selected. Config unchanged."
  exit 0
fi

_write_conf "${SELECTED_NAMES[@]}"
_patch_zshrc

echo ""
echo "  Enabled: ${SELECTED_NAMES[*]}"
echo ""
echo "  Restart your shell or run:  source ~/.zshrc"
echo ""
