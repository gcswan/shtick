# @name: killport
# @description: Kill processes listening on TCP ports, port ranges, or any mix of them
# @usage: killport [-f|--force] [-n|--dry-run] <port|start-end>[,...] ...
# @example: killport 3000 | killport 3000-3005 | killport 3000-3005 8080 5173,5174

killport() {
  local force=false dry_run=false
  local usage="Usage: killport [-f|--force] [-n|--dry-run] <port|start-end>[,...] ..."
  local -a specs

  while (( $# )); do
    case "$1" in
      -f|--force)   force=true ;;
      -n|--dry-run) dry_run=true ;;
      -h|--help)
        echo "$usage"
        echo "  -f, --force    send SIGKILL instead of SIGTERM"
        echo "  -n, --dry-run  list matching processes without killing them"
        echo "Examples: killport 3000 | killport 3000-3005 | killport 3000-3005 8080 5173,5174"
        return 0
        ;;
      -*) echo "killport: unknown option '$1'" >&2; echo "$usage" >&2; return 1 ;;
      *)  specs+=( ${(s:,:)1} ) ;;
    esac
    shift
  done

  if (( ! ${#specs} )); then
    echo "$usage" >&2
    return 1
  fi

  # Validate each spec and turn it into an lsof selector (lsof accepts ranges natively)
  local spec lo hi
  local -a selectors
  for spec in $specs; do
    if [[ ! "$spec" =~ '^([0-9]+)(-([0-9]+))?$' ]]; then
      echo "killport: invalid port or range '$spec'" >&2
      return 1
    fi
    lo=$match[1]
    hi=${match[3]:-$lo}
    if (( lo < 1 || hi > 65535 || lo > hi )); then
      echo "killport: port range out of bounds '$spec' (1-65535, start <= end)" >&2
      return 1
    fi
    selectors+=( -iTCP:$lo-$hi )
  done

  # Listeners only, so clients connected to these ports (e.g. browser tabs) are left alone
  local out
  out=$(lsof -nP -sTCP:LISTEN -Fpcn $selectors 2>/dev/null)

  local line pid cmd
  local -a rows pids
  local -A cmds
  for line in ${(f)out}; do
    case "$line" in
      p*) pid=${line#p} ;;
      c*) cmds[$pid]=${line#c} ;;
      n*) rows+=( "${line##*:} $pid" ) ;;
    esac
  done

  if (( ! ${#rows} )); then
    echo "Nothing listening on ${(j:, :)specs}"
    return 1
  fi

  # One row per port/PID pair (IPv4 and IPv6 listeners collapse), sorted by port
  local row port
  for row in ${(onu)rows}; do
    port=${row%% *}
    pid=${row##* }
    printf "  %-6s %s (PID %s)\n" "$port" "${cmds[$pid]}" "$pid"
    pids+=( $pid )
  done
  pids=( ${(u)pids} )

  $dry_run && return 0

  if $force; then
    kill -KILL $pids
    echo "Killed ${#pids} process(es) with SIGKILL"
    return
  fi

  kill -TERM $pids

  # Give processes up to ~2s to exit cleanly, then report stragglers
  local i
  local -a alive
  for i in {1..20}; do
    alive=()
    for pid in $pids; do
      kill -0 $pid 2>/dev/null && alive+=( $pid )
    done
    (( ${#alive} )) || break
    sleep 0.1
  done

  if (( ${#alive} )); then
    echo "Still running after SIGTERM: ${(j:, :)alive}. Retry with: killport -f ${(j: :)specs}" >&2
    return 1
  fi
  echo "Stopped ${#pids} process(es)"
}
