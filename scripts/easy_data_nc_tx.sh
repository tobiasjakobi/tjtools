#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

function __tar_create {
  tar --create --file - --preserve-permissions --xattrs-include='*.*' \
    --numeric-owner --directory="${1}" ./
}

function easy_data_nc_tx {
  local use_zstd=0

  if [[ "${1}" == "--zstd" ]]; then
    use_zstd=1
    shift
  fi

  if [[ ${use_zstd} -eq 1 ]]; then
    __tar_create "${1}" | zstd --compress --stdout -9 | pv | nc -q 5 -l -p 12345
  else
    __tar_create "${1}" | pv | nc -q 5 -l -p 12345
  fi
}
