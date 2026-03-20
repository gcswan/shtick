# @name: killport
# @description: Kill the process listening on a given TCP port
# @usage: killport [-f|--force] <port>

killport() {
  local port="$1" force=false

  if [[ "$port" == "-f" || "$port" == "--force" ]]; then
    force=true
    port="${2:-}"
  fi

  if [[ -z "$port" ]]; then
    echo "Usage: killport [-f|--force] <port>"
    return 1
  fi

  local pid
  pid=$(lsof -t -i tcp:"$port" 2>/dev/null)
  if [[ -z "$pid" ]]; then
    echo "No process found on port $port"
    return 1
  fi

  echo "Killing PID(s): $pid on port $port"
  if $force; then
    kill -9 $pid
  else
    kill $pid || { echo "SIGTERM failed, use killport -f $port to force"; return 1; }
  fi
}
alias kp='killport'
