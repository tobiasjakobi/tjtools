#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

function backup_bootstrap {
  local host="audioserver"
  local target="iqn.2021-05.org.${host}:usb"

  local uuid="11df2963-0a3b-44c9-bb31-3885b3de6eaa"
  local retries=5

  local mountpoint="/mnt/blackHole"
  local mountunit="mnt-blackHole.mount"

  local retry
  local fail

  systemctl isolate multi-user.target
  systemctl start iscsid

  iscsiadm -m node -T ${target} --login
  if [[ $? -ne 0 ]]; then
    echo "error: login to iSCSI target failed"
    return 1
  fi

  retry=0
  fail=0

  echo "info: waiting for container device..."

  while true; do
    if [[ -e /dev/disk/by-uuid/${uuid} ]]; then
      break
    fi

    if [[ ${retry} -eq ${retries} ]]; then
      fail=1
      break
    fi

    ((retry++))
    sleep 1s
  done

  if [[ ${fail} -eq 0 ]]; then
    echo "info: now loading container device..."

    systemctl start "${mountunit}"

    if [[ -f ${mountpoint}/backup.sh ]]; then
      echo "info: handing execution to container script..."

      ${mountpoint}/backup.sh
    else
      echo "error: backup script missing"
    fi

    systemctl stop "${mountunit}"
  else
    echo "error: container device timeout"
  fi

  iscsiadm -m node -T ${target} --logout
}

backup_bootstrap "$@"
