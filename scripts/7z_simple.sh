#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

set -e
set -u

function print_usage {
  echo "Usage: ${0} [--split=<splitsize>] [--prefix=<filename-prefix>] [--location=<output-location>] <directory>"
}

function 7z_simple {
  local split prefix location arg

  local filebase working
  local current opts

  if [[ -z "${1}" ]]; then
    print_usage

    return 1
  fi

  while [[ $# -ne 0 ]]; do
    case "${1}" in
      "--split="* )
        split=${1#'--split='} ;;

      "--prefix="* )
        prefix=${1#'--prefix='} ;;

      "--location="* )
        location=${1#'--location='} ;;

      * )
        arg=${1} ;;
    esac

    shift
  done

  if [[ -z "${arg}" ]]; then
    echo "error: directory argument missing"
    print_usage

    return 2
  fi

  if [[ ! -d "${arg}" ]]; then
    echo "error: directory not found: ${arg}"
    print_usage

    return 3
  fi

  filebase=$(basename "${arg}")
  working=$(dirname "${arg}")
  current=$(realpath .)

  if [[ -n "${split}" ]]; then
    opts="-v${split}"
  fi

  if [[ -n "${location}" ]]; then
    if [[ -d "${location}" ]]; then
      current=$(realpath "${location}")
    else
      echo "info: output location not found, ignoring: ${location}"
    fi
  fi

  pushd "${working}" > /dev/null
    7z a -bd -t7z -mx=9 -m0=lzma2 ${opts} "${current}/${prefix}${filebase}.7z" "${filebase}"
  popd > /dev/null
}

7z_simple "$@"
