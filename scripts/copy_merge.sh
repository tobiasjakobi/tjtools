#!/usr/bin/env bash

function copy_merge {
  local source_dir
  local target_dir

  if [[ ! -d "${1}" ]]; then
    echo "error: invalid source directory: ${1}"
    return 1
  fi

  source_dir="${1}"

  if [[ ! -d "${2}" ]]; then
    echo "error: invalid target directory: ${2}"
    return 2
  fi

  target_dir="${2}"

  tar --create --file - --preserve-permissions --numeric-owner --directory="${source_dir}" ./ | \
    tar --extract --file - --preserve-permissions --keep-old-files --verbose --numeric-owner --directory="${target_dir}"
}

copy_merge "$@"
