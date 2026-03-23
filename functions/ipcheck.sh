# @name: ipcheck
# @description: Show public IP, local network info, VPN status, and open ipleak.net
# @usage: ipcheck
# @platform: macOS

ipcheck() {
  local BOLD='\033[1m'
  local DIM='\033[2m'
  local GREEN='\033[32m'
  local YELLOW='\033[33m'
  local CYAN='\033[36m'
  local RESET='\033[0m'

  local divider
  divider=$(printf '─%.0s' {1..60})

  # --- Public IP ---
  echo
  printf "${BOLD}${CYAN}Public IP${RESET}\n"
  printf "${DIM}%s${RESET}\n" "$divider"
  local PUBLIC_IP
  PUBLIC_IP=$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null || echo "")
  if [[ -z "$PUBLIC_IP" ]]; then
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null || echo "unavailable")
  fi
  printf "  IP: ${BOLD}%s${RESET}\n" "$PUBLIC_IP"

  # --- VPN Status ---
  echo
  printf "${BOLD}${CYAN}VPN Status${RESET}\n"
  printf "${DIM}%s${RESET}\n" "$divider"
  local VPN_FOUND=false

  # Check for utun interfaces (WireGuard, system VPN)
  local UTUN_IFACES
  UTUN_IFACES=$(ifconfig | grep -E '^utun[0-9]+:' | awk -F: '{print $1}' 2>/dev/null || true)
  if [[ -n "$UTUN_IFACES" ]]; then
    local iface addr
    for iface in $UTUN_IFACES; do
      addr=$(ifconfig "$iface" 2>/dev/null | awk '/inet / {print $2}' || true)
      if [[ -n "$addr" ]]; then
        printf "  ${GREEN}Active${RESET}: %s (%s)\n" "$iface" "$addr"
        VPN_FOUND=true
      fi
    done
  fi

  # Check for ipsec interfaces
  local IPSEC_IFACES
  IPSEC_IFACES=$(ifconfig | grep -E '^ipsec[0-9]+:' | awk -F: '{print $1}' 2>/dev/null || true)
  if [[ -n "$IPSEC_IFACES" ]]; then
    local iface addr
    for iface in $IPSEC_IFACES; do
      addr=$(ifconfig "$iface" 2>/dev/null | awk '/inet / {print $2}' || true)
      if [[ -n "$addr" ]]; then
        printf "  ${GREEN}Active${RESET}: %s (%s)\n" "$iface" "$addr"
        VPN_FOUND=true
      fi
    done
  fi

  # Check macOS system VPN configs
  local SCUTIL_VPN
  SCUTIL_VPN=$(scutil --nc list 2>/dev/null || true)
  if [[ -n "$SCUTIL_VPN" ]]; then
    local line name
    while IFS= read -r line; do
      if echo "$line" | grep -q "Connected"; then
        name=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/')
        printf "  ${GREEN}Connected${RESET}: %s\n" "$name"
        VPN_FOUND=true
      elif echo "$line" | grep -q "Disconnected"; then
        name=$(echo "$line" | sed 's/.*"\(.*\)".*/\1/')
        printf "  ${DIM}Disconnected: %s${RESET}\n" "$name"
      fi
    done <<< "$SCUTIL_VPN"
  fi

  # Check for common VPN processes
  local VPN_PROCS="" proc
  for proc in "Mullvad VPN" "openvpn" "wireguard-go" "tailscaled" "nordvpn" "ExpressVPN" "Windscribe" "cloudflared" "GlobalProtect" "PanGPS" "gpd"; do
    if pgrep -fi "$proc" >/dev/null 2>&1; then
      VPN_PROCS="${VPN_PROCS}  ${GREEN}Running${RESET}: ${proc}\n"
      VPN_FOUND=true
    fi
  done
  if [[ -n "$VPN_PROCS" ]]; then
    printf "$VPN_PROCS"
  fi

  if ! $VPN_FOUND; then
    printf "  ${YELLOW}No active VPN detected${RESET}\n"
  fi

  # --- Network Interfaces ---
  echo
  printf "${BOLD}${CYAN}Network Interfaces${RESET}\n"
  printf "${DIM}%s${RESET}\n" "$divider"

  local WIFI_DEVICE WIFI_IP SSID
  WIFI_DEVICE=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2}' || true)
  if [[ -n "$WIFI_DEVICE" ]]; then
    WIFI_IP=$(ipconfig getifaddr "$WIFI_DEVICE" 2>/dev/null || echo "not connected")
    SSID=$(ipconfig getsummary "$WIFI_DEVICE" 2>/dev/null | awk -F': ' '/SSID :/ {print $2}' || networksetup -getairportnetwork "$WIFI_DEVICE" 2>/dev/null | sed 's/Current Wi-Fi Network: //' || echo "unknown")
    printf "  Wi-Fi (%s): %s" "$WIFI_DEVICE" "$WIFI_IP"
    if [[ "$WIFI_IP" != "not connected" ]]; then
      printf "  SSID: %s" "$SSID"
    fi
    echo
  fi

  local ETH_DEVICE ETH_IP
  ETH_DEVICE=$(networksetup -listallhardwareports 2>/dev/null | awk '/Ethernet/{getline; print $2}' | head -1 || true)
  if [[ -n "$ETH_DEVICE" ]]; then
    ETH_IP=$(ipconfig getifaddr "$ETH_DEVICE" 2>/dev/null || echo "not connected")
    printf "  Ethernet (%s): %s\n" "$ETH_DEVICE" "$ETH_IP"
  fi

  # --- DNS ---
  echo
  printf "${BOLD}${CYAN}DNS Configuration${RESET}\n"
  printf "${DIM}%s${RESET}\n" "$divider"
  local DNS_SERVERS
  DNS_SERVERS=$(scutil --dns 2>/dev/null | awk '/nameserver\[/ {print $3}' | sort -u | head -5 || true)
  if [[ -n "$DNS_SERVERS" ]]; then
    local dns
    while IFS= read -r dns; do
      printf "  %s\n" "$dns"
    done <<< "$DNS_SERVERS"
  else
    printf "  ${DIM}Could not determine DNS servers${RESET}\n"
  fi

  # --- Default Gateway ---
  echo
  printf "${BOLD}${CYAN}Default Gateway${RESET}\n"
  printf "${DIM}%s${RESET}\n" "$divider"
  local GATEWAY
  GATEWAY=$(route -n get default 2>/dev/null | awk '/gateway:/ {print $2}' || netstat -rn 2>/dev/null | awk '/^default.*en/ {print $2; exit}' || echo "unknown")
  printf "  %s\n" "$GATEWAY"

  # --- Open ipleak.net ---
  echo
  printf "${DIM}%s${RESET}\n" "$divider"
  local URL
  if [[ "$PUBLIC_IP" != "unavailable" ]]; then
    URL="https://ipleak.net/?q=${PUBLIC_IP}"
    printf "${BOLD}Opening:${RESET} %s\n" "$URL"
    open "$URL" 2>/dev/null || printf "${YELLOW}Could not open browser. Visit manually: %s${RESET}\n" "$URL"
  else
    URL="https://ipleak.net/"
    printf "${YELLOW}Could not determine public IP. Opening ipleak.net without query.${RESET}\n"
    open "$URL" 2>/dev/null || printf "${YELLOW}Visit manually: %s${RESET}\n" "$URL"
  fi
  echo

}
