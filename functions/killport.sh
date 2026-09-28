# @name: killport
# @description: List TCP listeners (all, or by port/range) and offer to kill them
# @usage: killport [-y|--yes] [-f|--force] [-n|--dry-run] [<port|start-end>[,...] ...]
# @example: killport | killport 3000 | killport 3000-3005 8080 5173,5174 | killport -y 8080

killport() {
  local force=false dry_run=false yes=false
  local usage="Usage: killport [-y|--yes] [-f|--force] [-n|--dry-run] [<port|start-end>[,...] ...]"
  local -a specs

  while (( $# )); do
    case "$1" in
      -y|--yes)     yes=true ;;
      -f|--force)   force=true ;;
      -n|--dry-run) dry_run=true ;;
      -fy|-yf)      force=true; yes=true ;;
      -h|--help)
        echo "$usage"
        echo "  With no ports, lists every TCP listener. Asks before killing unless -y."
        echo "  -y, --yes      kill without asking"
        echo "  -f, --force    send SIGKILL instead of SIGTERM"
        echo "  -n, --dry-run  list matching processes without killing them"
        echo "Examples: killport | killport 3000 | killport 3000-3005 8080 5173,5174 | killport -y 8080"
        return 0
        ;;
      -*) echo "killport: unknown option '$1'" >&2; echo "$usage" >&2; return 1 ;;
      *)  specs+=( ${(s:,:)1} ) ;;
    esac
    shift
  done

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
  (( ${#selectors} )) || selectors=( -iTCP )

  # Listeners only, so clients connected to these ports (e.g. browser tabs) are left alone
  local out
  out=$(lsof -nP -sTCP:LISTEN -Fpcn $selectors 2>/dev/null)

  local line pid cmd
  local -a rows pids
  local -A cmds pid_ports
  for line in ${(f)out}; do
    case "$line" in
      p*) pid=${line#p} ;;
      c*) cmds[$pid]=${line#c} ;;
      n*) rows+=( "${line##*:} $pid" ) ;;
    esac
  done

  if (( ! ${#rows} )); then
    if (( ${#specs} )); then
      echo "Nothing listening on ${(j:, :)specs}"
    else
      echo "Nothing listening on TCP"
    fi
    return 1
  fi

  # One row per port/PID pair (IPv4 and IPv6 listeners collapse), sorted by port
  local row port
  printf "  %-6s %s\n" "PORT" "PROCESS"
  for row in ${(onu)rows}; do
    port=${row%% *}
    pid=${row##* }
    printf "  %-6s %s (PID %s)\n" "$port" "${cmds[$pid]}" "$pid"
    pids+=( $pid )
    pid_ports[$pid]+="${pid_ports[$pid]:+ }$port"
  done
  pids=( ${(u)pids} )

  $dry_run && return 0

  if ! $yes; then
    if [[ ! -t 0 ]]; then
      echo "killport: not a terminal; pass -y to kill without asking" >&2
      return 1
    fi
    if ! read -q "?Kill ${#pids} process(es)? [y/N] "; then
      echo
      echo "Nothing killed"
      return 1
    fi
    echo
  fi

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
    local -a alive_ports
    for pid in $alive; do
      alive_ports+=( ${(s: :)pid_ports[$pid]} )
    done
    echo "Still running after SIGTERM: ${(j:, :)alive}. Retry with: killport -fy ${(onu)alive_ports}" >&2
    return 1
  fi
  echo "Stopped ${#pids} process(es)"
}
