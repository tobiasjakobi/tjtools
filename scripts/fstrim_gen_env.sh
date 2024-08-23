#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

set -e
set -u

function __mount_get_fs {
  local mountdata
  local num_data

  read -ra mountdata <<<"$@"

  num_data=${#mountdata[@]}

  if [[ ${num_data} -eq 11 ]]; then
    echo "${mountdata[8]}"
  elif [[ ${num_data} -eq 12 ]]; then
    echo "${mountdata[9]}"
  else
    echo "unknown"
  fi
}

function __mountinfo_filter_fs {
  local mountinfo
  local idx
  local num_mounts
  local cur_mount
  local mount_fs

  readarray -t mountinfo < "${1}"

  num_mounts=${#mountinfo[@]}

  idx=0
  while [[ ${idx} -ne ${num_mounts} ]]; do
    cur_mount="${mountinfo[$idx]}"

    mount_fs=$(__mount_get_fs "${cur_mount}")
    if [[ "${mount_fs}" != "${2}" ]]; then
      echo "${cur_mount}"
    fi

    ((idx++))
  done
}

function __mountinfo_remove_btrfs {
  local tmpfile

  tmpfile=$(mktemp --tmpdir=/tmp mountinfo.no_btrfs.XXXXXXXXXX)

  __mountinfo_filter_fs "/proc/self/mountinfo" "btrfs" > "${tmpfile}"

  echo "${tmpfile}"
}

function fstrim_gen_env {
  local env_file="/run/fstrim.environment"
  local env_key="mountinfo_no_btrfs"

  local env_value=$(__mountinfo_remove_btrfs)

  echo "${env_key}=${env_value}" > "${env_file}"
}

fstrim_gen_env "$@"
