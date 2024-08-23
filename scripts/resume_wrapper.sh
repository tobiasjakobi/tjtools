#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

function resume_wrapper {
  local containers
  local num_container
  local idx
  local container

  read -ra containers < <(find /dev/mapper -type l)

  num_container=${#containers[@]}

  idx=0
  while [[ ${idx} -lt ${num_container} ]]; do
    container=${containers[${idx}]}

    echo "Resuming LUKS container: ${container}..."
    /sbin/cryptsetup luksResume "${container}"

    ((idx++))
  done

  # Terminate the outer kmscon session.
  kill ${PPID}
}

resume_wrapper "$@"
