#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

function detect_display {
  local preferred_output
  local dp_status
  local outputs

  source /etc/sway/wayland-environment

  preferred_output="${GAMESCOPE_PREFERRED_OUTPUT}"
  if [[ -z "${preferred_output}" ]]; then
    return
  fi

  # Split into array so that we can easier loop over it.
  IFS=',' read -a outputs <<<"${preferred_output}"
  for output in "${outputs[@]}"; do
    dp_status="/sys/class/drm/card0-${output}/status"

    if [[ -f "${dp_status}" ]]; then
      echo "info: performing re-detect of external display: ${output}"

      echo -n detect > ${dp_status}
    fi
  done
}

detect_display "$@"
