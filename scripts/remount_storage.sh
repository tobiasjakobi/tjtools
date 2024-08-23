#!/usr/bin/env bash

function remount_storage {
  local storage

  if [[ -z "${1}" ]]; then
    echo "error: missing storage argument"
    return 1
  fi

  if [[ ! -d "${1}" ]]; then
    echo "error: invalid storage argument"
    return 2
  fi

  storage="${1}"

  mount -o remount,rw "${storage}" && read && mount -o remount,ro "${storage}"
}

remount_storage "$@"
