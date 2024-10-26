#!/usr/bin/env bash

function openvpn_netdev {
  local netdev
  local netdev_addr
  local errcode

  if [[ -z "${1}" ]]; then
    echo "error: missing netdev argument"

    return 1
  fi

  netdev="${1}"
  shift

  netdev_addr=$(ip -json -4 addr show dev "${netdev}" | jq --raw-output .[0].addr_info[0].local)
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: failed to determine netdev address: ${errcode}"

    return 2
  fi

  /usr/sbin/openvpn --local "${netdev_addr}" "$@"
}

openvpn_netdev "$@"
