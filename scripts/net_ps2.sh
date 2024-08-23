#!/usr/bin/env bash

alive_loop=0

trap "alive_loop=0" SIGINT SIGTERM

function ping_loop {
  local count

  count=0
  replies=0

  while true; do
    ping -q -c 1 -w 2 "${1}" &> /dev/null

    if [[ ${alive_loop} -eq 0 ]]; then
      break
    fi

    if [[ $? -eq 0 ]]; then
      ((replies++))
    fi

    ((count++))
    if [[ ${count} -eq ${2} ]]; then
      break
    fi

    sleep 3s
  done

  echo ${replies}
}

function net_ps2 {
  local target="playstation2"
  local replies

  if [[ -z "${1}" ]]; then
    echo "error: network device argument missing"
    return 1
  fi

  echo "info: PS2 keep-alive ping started..."

  alive_loop=1

  while true; do
    replies=$(ping_loop "${target}" 15)

    if [[ ${alive_loop} -eq 0 ]]; then
      break
    fi

    if [[ ${replies} -lt 3 ]]; then
      echo "info: high ping loss, restarting interface..."

      ip link set dev "${1}" down
      sleep 1s
      networkctl reconfigure "${1}"
    fi
  done

  echo "info: PS2 keep-alive ping ended..."
}

net_ps2 "$@"
