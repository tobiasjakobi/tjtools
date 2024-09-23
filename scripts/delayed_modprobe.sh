#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

function delayed_modprobe {
  local delay
  local module_name

  if [[ -z "${1}" ]]; then
    echo "error: missing delay argument"

    return 1
  fi

  delay="${1}"

  if [[ -z "${2}" ]]; then
    echo "error: missing module name argument"

    return 2
  fi

  module_name="${2}"

  sleep "${delay}" && modprobe --ignore-install "${module_name}"
}

delayed_modprobe "$@"
