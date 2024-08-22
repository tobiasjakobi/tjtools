#!/usr/bin/env bash

function env_helper {
  local _server="${ENV_PULSE_SERVER}"
  local _cookie="${ENV_PULSE_COOKIE}"

  unset ENV_PULSE_SERVER
  unset ENV_PULSE_COOKIE

  if [[ -f "${_cookie}" ]]; then
    echo "info: PA cookie available (inside container)"

    if [[ -d "${XDG_CONFIG_HOME}" ]]; then
      mkdir --parents "${XDG_CONFIG_HOME}/pulse"
      ln --force --symbolic "${_cookie}" "${XDG_CONFIG_HOME}/pulse/cookie"
    fi
  fi

  if [[ -n "${_server}" ]]; then
    echo "info: PA server available (inside container)"

    env PULSE_SERVER="${_server}" "$@"
  else
    "$@"
  fi
}

env_helper "$@"
