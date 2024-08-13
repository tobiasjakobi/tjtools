#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-2.0

function sysfs_write {
  local delay=1s
  local num_retries=10

  local value
  local sysfs_path
  local retry

  sysfs_path="/sys/${1}"
  value="${2}"
  retry=0

  while [[ ${retry} -lt ${num_retries} ]]; do
    if [[ -f "${sysfs_path}" ]]; then
      echo -n "${value}" > "${sysfs_path}"

      return 0
    fi

    sleep ${delay}
    ((retry++))
  done

  return 1
}

sysfs_write "$@"
