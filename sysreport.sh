#!/bin/bash
set -eou pipefail

# --- config ---
WARN=75
CPU=90

# --- colors ---
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
reset='\033[0m'

# --- helpers ---
ok() { printf "${green}OK${reset}"; }
warn() { printf "${yellow}WARN${reset}"; }
crit() { printf "${red}CRIT${reset}"; }

# a colorizer that prints a usage percentage with the right status
usage_status() {
  local pct=$1
  if ((pct >= CPU)); then
    crit
  elif ((pct >= WARN)); then
    warn
  else
    ok
  fi

}

# --- report sections ---
section() { printf "\n=== %s ===\n" "$1"; }

system_info() {
  section "SYSTEM"

  HOSTNAME=$(cat /etc/hostname)
  IP=$(ip -4 addr show dev $(ip route show | awk '{print $5}' | head -1) | grep inet | awk '{print $2}' | cut -d '/' -f1)
  GW=$(ip route show default | awk '{print $3}')
  DNS=$(awk '/nameserver/ {print $2}' /etc/resolv.conf)
  OS=$(grep ^NAME /etc/os-release | cut -d= -f2 | tr -d '"')
  KERNEL=$(uname -r)
  UPTIME=$(uptime -p)

  printf "%-12s %s\n" "Hostname :" "$HOSTNAME"
  printf "%-12s %s\n" "OS :" "$OS"
  printf "%-12s %s\n" "Kernel :" "$KERNEL"
  printf "%-12s %s\n" "Uptime :" "$UPTIME"
  printf "%-12s %s\n" "IP Adress :" "$IP"
  printf "%-12s %s\n" "GATEWAY :" "$GW"
  printf "%-12s %s\n" "DNS:" "$DNS"

}

connectivity_check() {
  section "Connectivity checking"
  if ping -c 3 -w 2 8.8.8.8 >/dev/null 2>&1; then
    echo "Internet: [OK]"
  else
    echo "Internet: [FAIL]"
  fi
}

load_and_mem_cpu() {
  section "LOAD and MEMORY and CPU"

  LOAD=$(cat /proc/loadavg | awk '{print $1}')
  MEMORY=$(free -m | grep Mem | awk '{print int($3 / $2 * 100)}')
  CPU_USAGE=$(vmstat 1 3 | tail -1 | awk '{print 100-$15}')

  printf "%-12s %s\n" "Load:" "$LOAD"
  printf "%-12s %3d%% [" "Memory:" "$MEMORY"
  usage_status "$MEMORY"
  printf "]\n"

  printf "%-12s %d%% [" "CPU:" "$CPU_USAGE"
  usage_status "$CPU_USAGE"
  printf "]\n"
}

disk_usage() {
  section "DISK"

  DISK_USAGE=$(df -h / | sed -n '2p' | awk '{print int($5)}')

  printf "%-12s %d%% [" "DISK_USAGE:" "$DISK_USAGE"
  usage_status "$DISK_USAGE"
  printf "]\n"
}

top_processess() {
  section "TOP_PROCESSESS"

  PROCESSESS=$(ps -eo pid,comm,%cpu --sort=-%cpu | head -6 | sed '1d')

  MEM=$(ps -eo pid,comm,%mem --sort=-%mem | head -6 | sed '1d')

  echo "Top CPU usage"
  printf "%s\n" "$PROCESSESS"

  echo

  echo "Top Memory Usage"
  printf "%s\n" "$MEM"
}

failed_services() {
  section "FAILED SERVICE"
  SERVICE=$(systemctl --failed | sed '/^$/d' | sed '1d')

  printf "%-12s %s\n" "Failed_services:" "$SERVICE"
}

zombie() {
  section "Zombie Process"
  ZOMBIE=$(ps -eo state | awk '$1=="Z" {count++} END {print count+0}')

  printf "%-12s %s\n" "Zombie Processes : " "$ZOMBIE"
}

main() {
  system_info
  connectivity_check
  load_and_mem_cpu
  disk_usage
  top_processess
  failed_services
  zombie
}

main "$@"
