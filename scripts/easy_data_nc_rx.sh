#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

function __tar_extract {
  tar --extract --file - --preserve-permissions --preserve-order \
    --xattrs-include='*.*' --numeric-owner --directory="${1}"
}

function easy_data_nc_rx {
  local use_zstd=0

  if [[ "${1}" == "--zstd" ]]; then
    use_zstd=1
    shift
  fi

  if [[ ${use_zstd} -eq 1 ]]; then
    nc -q 5 "${1}" 12345 | zstd --decompress --stdout | pv | __tar_extract "${2}"
  else
    nc -q 5 "${1}" 12345 | pv | __tar_extract "${2}"
  fi
}
