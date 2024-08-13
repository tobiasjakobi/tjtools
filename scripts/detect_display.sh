#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-2.0

function detect_display {
  local preferred_output
  local dp_status

  source /etc/sway/wayland-environment

  preferred_output="{GAMESCOPE_PREFERRED_OUTPUT}"

  if [[ -n "${preferred_output}" ]]; then
    dp_status="/sys/class/drm/card0-${preferred_output}/status"

    if [[ -f "${dp_status}" ]]; then
      echo "info: performing re-detect of external display: ${preferred_output}"

      echo -n detect > ${dp_status}
    fi
  fi
}

detect_display "$@"
