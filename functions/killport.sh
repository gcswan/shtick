# @name: killport
# @description: Kill the process listening on a given TCP port
# @usage: killport <port>

killport() {
  local port=$1
  if [ -z "$port" ]; then
    echo "Usage: killport <port>"
    return 1
  fi
  local pid
  pid=$(sudo lsof -t -i tcp:$port)
  if [ -n "$pid" ]; then
    echo "Killing PID(s): $pid on port $port"
    kill -9 $pid
  else
    echo "No process found on port $port"
  fi
}
alias kp='killport'
