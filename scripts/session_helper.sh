#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

function dbus_setup {
  dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS DISPLAY XAUTHORITY
}

function steam_setup {
  if [[ -f "${MANGOHUD_CONFIGFILE}" ]]; then
    echo "no_display" > "${MANGOHUD_CONFIGFILE}"
  fi
}

function steam_cleanup {
  if [[ -f "${MANGOHUD_CONFIGFILE}" ]]; then
    rm "${MANGOHUD_CONFIGFILE}"
  fi

  if [[ -f "${GAMESCOPE_LIMITER_FILE}" ]]; then
    rm "${GAMESCOPE_LIMITER_FILE}"
  fi
}

function session_helper {
  local session_type

  if [[ -z "${1}" ]]; then
    echo "error: missing session type argument"

    return 1
  fi

  session_type="${1}"
  shift

  case "${session_type}" in
    "--kitty" )
      dbus_setup
      kitty --override linux_display_server=x11 $@ ;;

    "--steam-gamepadui" )
      dbus_setup
      steam_setup
      # TODO: get -steampal -steamdeck arguments working
      GSETTINGS_BACKEND=memory steam -gamepadui -steamos3 $@
      steam_cleanup ;;

    "--steam-shutdown" )
      GSETTINGS_BACKEND=memory steam -shutdown ;;

    "--help" )
      echo "Usage: ${0} --kitty|--steam-gamepadui|--steam-shutdown <arguments>"

      return 0 ;;

    * )
      echo "error: invalid session type: ${session_type}"

      return 2 ;;
  esac
}

session_helper "$@"
