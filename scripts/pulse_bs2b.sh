#!/usr/bin/env bash

declare -r msg="PulseAudio LADSPA/bs2b plugin"

declare -i module_id=-1

function __usage {
  echo -e "Supported bs2b profiles:"
  echo -e "\t default: default: cutoff = 700Hz/260us, level = 4.5 dB"
  echo -e "\t chu-moy: Chu Moy: cutoff = 700Hz/260us, level = 6.0 dB"
  echo -e "\t jan-meier: Jan Meier: cutoff = 650Hz/280us, level = 9.5 dB"
}

function __load_bs2b {
  pactl load-module module-ladspa-sink sink_name=headphone_crossfeed master="@DEFAULT_SINK@" plugin=bs2b label=bs2b control="${1}"
}

function __start {
  local ctrl_values
  local errcode

  case "${1}" in
    "default" )
      echo "info: loading bs2b with default profile"
      ctrl_values="700,4.5" ;;

    "chu-moy" )
      echo "info: loading bs2b with Chu Moy profile"
      ctrl_values="700,6.0" ;;

    "jan-meier" )
      echo "info: loading bs2b with Jan Meier profile"
      ctrl_values="650,9.5" ;;

    * )
      echo "error: ${msg}: unknown profile"
      __usage

      return 2 ;;
  esac

  module_id=$(__load_bs2b "${ctrl_values}")

  errcode=$?
  if [[ ${errcode} -ne 0 ]]; then
    echo "error: ${msg}: failed to load profile ${1}: ${errcode}"

    return 3
  fi

  echo "info: ${msg}: loaded profile ${1} with module ID: ${module_id}"

  return 0
}

function __stop {
  if [[ ${module_id} -ge 0 ]]; then
    echo "info: ${msg}: unloading module ID: ${module_id}"

    pactl unload-module "${module_id}"
  fi
}

function __signal {
  echo "info: signal received"
}

function pulse_bs2b {
  trap __signal SIGINT SIGTERM

  if [[ -z "${1}" ]]; then
    echo "error: ${msg}: missing profile argument"

    return 1
  fi

  __start "${1}"
  if [[ $? -ne 0 ]]; then
    echo "error: ${msg}: start failed"

    return 2
  fi

  sleep infinity

  __stop
}

pulse_bs2b "$@"
