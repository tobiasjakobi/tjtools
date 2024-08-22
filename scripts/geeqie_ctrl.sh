#!/usr/bin/env bash

function geeqie_ctrl {
  local pid windowid key

  pid=$(pgrep geeqie | head -n1)
  [[ -z "${pid}" ]] && return

  windowid=$(xdotool search --all --onlyvisible --pid $pid --name "Geeqie" | tail -n1)
  [[ -z "${windowid}" ]] && return

  case "${1}" in
    "--previous" )
      key="BackSpace" ;;

    "--next" )
      key="space" ;;

    * )
      echo "Usage: ${0} --previous|--next"
      return 1 ;;
  esac

  xdotool windowactivate --sync $windowid key $key
}

geeqie_ctrl "$@"
