#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

set -e
set -u

function print_usage {
  echo "Usage: ${1} [--split=<splitsize>] [--prefix=<filename-prefix>] [--location=<output-location>] <directory>"
}

function 7z_simple {
  local split="--split="
  local prefix="--prefix="
  local location="--location="

  local split_value=
  local prefix_value=
  local location_value=
  local input_directory=
  local options=

  local filebase
  local working
  local current

  if [[ $# -eq 0 ]]; then
    print_usage "${0}"

    return 1
  fi

  while [[ $# -ne 0 ]]; do
    case "${1}" in
      "${split}"* )
        split_value="${1#${split}}" ;;

      "${prefix}"* )
        prefix_value="${1#${prefix}}" ;;

      "${location}"* )
        location_value="${1#${location}}" ;;

      * )
        input_directory="${1}" ;;
    esac

    shift
  done

  if [[ -z "${input_directory}" ]]; then
    echo "error: directory argument missing"
    print_usage "${0}"

    return 2
  fi

  if [[ ! -d "${input_directory}" ]]; then
    echo "error: directory not found: ${input_directory}"
    print_usage "${0}"

    return 3
  fi

  if [[ -n "${split_value}" ]]; then
    options="-v${split_value}"
  fi

  filebase=$(basename "${input_directory}")
  working=$(dirname "${input_directory}")
  current=$(realpath "${PWD}")

  if [[ -n "${location_value}" ]]; then
    if [[ -d "${location_value}" ]]; then
      current=$(realpath "${location_value}")
    else
      echo "info: output location not found, ignoring: ${location_value}"
    fi
  fi

  pushd "${working}" > /dev/null
    7z a -bd -t7z -mx=9 -m0=lzma2 ${options} "${current}/${prefix_value}${filebase}.7z" "${filebase}"
  popd > /dev/null
}

7z_simple "$@"
