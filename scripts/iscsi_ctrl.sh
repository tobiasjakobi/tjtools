#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-2.0

function print_usage {
  echo "Usage: ${1} optical|usb|universe|--discover"
}

function iscsi_ctrl {
  local target
  local discover=0

  case "${1}" in
    "optical" )
      target="iqn.2020-02.org.audioserver:optical" ;;

    "usb" )
      target="iqn.2020-02.org.audioserver:usb" ;;

    "universe" )
      target="iqn.2004-04.com.qnap:ts-832px:iscsi.storage.64b5db" ;;

    "--discover" )
      echo "info: doing iSCSI discover on: ${2}"

      discover=1
      target="${2}" ;;

    "--help" )
      print_usage "${0}"
      return 0 ;;

    * )
      echo "error: unknown target selected: ${1}"
      return 1 ;;
  esac

  shift

  if [[ ${discover} -eq 1 ]]; then
    iscsiadm --mode discovery --type=sendtargets --portal="${target}"
  else
    iscsiadm --mode node --targetname="${target}" "$@"
  fi
}

iscsi_ctrl "$@"
