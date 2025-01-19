# SPDX-License-Identifier: GPL-2.0
#
# Bash functions intended for regular users of the system.

## Helpers

function __vnc_internal {
  local unix_socket="/tmp/wayvnc-local.sock"
  local remote_socket="/tmp/wayvnc-remote.sock"

  local outer_funcname
  local vnc_host
  local cmd
  local capture_output

  local additional_args
  local remote_cmd

  outer_funcname="${1}"
  vnc_host="${2}"
  cmd="${3}"
  capture_output="${4}"

  shift 4

  if [[ -n "${capture_output}" ]]; then
    additional_args="--output=${capture_output}"
  else
    additional_args=""
  fi

  remote_cmd="env WAYLAND_DISPLAY=wayland-1 wayvnc --unix-socket --keyboard=de-nodeadkeys --render-cursor --gpu ${additional_args} ${unix_socket}"

  case "${cmd}" in
    "--spawn" )
      rm --force ${remote_socket}
      ssh -L ${remote_socket}:${unix_socket} "${vnc_host}" "${remote_cmd}" ;;

    "--connect" )
      vncviewer -FullscreenSystemKeys ${remote_socket} ;;

    "--forward-only" )
      rm --force ${remote_socket}
      ssh -N -o ExitOnForwardFailure=yes -L ${remote_socket}:${unix_socket} "${vnc_host}" ;;

    "--exit" )
      ssh "${vnc_host}" "wayvncctl wayvnc-exit" ;;

    * )
      echo "Usage: ${outer_funcname} --spawn|--connect|--forward-only|--exit" ;;
  esac
}

## Bash functions

function audioserver_bs2b {
  local profile
  local cmd

  case "${1}" in
    "d" )
      profile="default" ;;

    "c" )
      profile="chu-moy" ;;

    "m" )
      profile="jan-meier" ;;

    "u" )
      profile="" ;;

    * )
      echo -e "Usage: ${FUNCNAME} d|c|m|u"
      echo -e "\t d: default profile"
      echo -e "\t c: Chu Moy profile"
      echo -e "\t m: Jan Meier profile"
      echo -e "\t u: unload all crossfeeds"

      return 1 ;;
  esac

  if [[ -z "${profile}" ]]; then
    cmd="systemctl --user stop pulse-bs2b@default.service pulse-bs2b@chu-moy.service pulse-bs2b@jan-meier.service"
  else
    cmd="systemctl --user start pulse-bs2b@${profile}.service"
  fi

  ssh audioserver "${cmd}"
}

function bluray_master {
  local source_dir
  local volume_id
  local output_file

  if [[ -z "${1}" ]]; then
    echo "Usage: ${FUNCNAME} <source directory> <volume ID> <output file>"

    return 0
  fi

  source_dir="${1}"

  if [[ -z "${2}" ]] || [[ -z "${3}" ]]; then
    echo "error: invalid argument"

    return 1
  fi

  volume_id="${2}"
  output_file="${3}"

  mkisofs -quiet -iso-level 4 -full-iso9660-filenames -udf -V "${volume_id}" -o "${output_file}" "${source_dir}"
}

# Fetch ReplayGain algorithm of the current track and adjust the preamp value of CMus accordingly.
function cmus_r128 {
  local status
  local algo
  local preamp

  status=$(cmus-remote -Q 2> /dev/null | grep "^tag ")
  if [[ -z "${status}" ]]; then
    return 0
  fi

  algo=$(echo "${status}" | grep "^tag replaygain_algorithm" | cut -d' ' -f3-)

  if [[ "${algo}" == "EBU R128" ]]; then
    echo "info: EBU R128 detected, setting preamp to 7.0dB"
    preamp="7.0"
  else
    echo "info: ReplayGain detected, setting preamp to 4.0dB"
    preamp="4.0"
  fi

  cmus-remote -C "set replaygain_preamp=${preamp}"
}

# Output nicely formatted CMus "Now Playing" status.
function cmus_status {
  local status
  local artist
  local title
  local album
  local output

  status=$(cmus-remote -Q 2> /dev/null | grep "^tag ")
  if [[ -z "${status}" ]]; then
    return 0
  fi

  artist=$(echo "${status}" | grep "^tag artist " | cut -d' ' -f3-)
  title=$(echo "${status}" | grep "^tag title " | cut -d' ' -f3-)
  album=$(echo "${status}" | grep "^tag album " | cut -d' ' -f3-)

  output="${artist} -"

  if [[ -n "${album}" ]]; then
    output+=" [${album}]"
  fi

  output+=" ${title}"

  echo "${output}"
}

# Convert file with CRLF (carriage return / line feed) endings to normal LF (unix style) endings.
function convert_crlf {
  local output

  if [[ ! -f "${1}" ]]; then
    echo "error: no such file: ${1}"

    return 1
  fi

  if [[ -n "${2}" ]]; then
    output="${2}"
  else
    output="${1}.noCRLF"
  fi

  if [[ -e "${output}" ]]; then
    echo "error: output already exists: ${output}"

    return 2
  fi

  cat "${1}" | tr -d '\15\32' > "${output}"
}

# Convert text files with various encodings to UTF8.
function convert_textenc {
  local input_path
  local output_path
  local fileinfo
  local file_type
  local charset

  if [[ ! -f "${1}" ]]; then
    echo "error: no such file: ${1}"

    return 1
  fi

  input_path="${1}"

  if [[ -n "${2}" ]]; then
    output_path="${2}"
  else
    output_path="${input_path}.utf8"
  fi

  if [[ -e "${output_path}" ]]; then
    echo "error: output already exists: ${output_path}"

    return 2
  fi

  fileinfo=$(file --brief --mime "${input_path}")
  file_type=$(echo "${fileinfo}" | cut -d';' -f1)
  charset=$(echo "${fileinfo}" | grep -o -E "charset=[[:print:]]+" | cut -d'=' -f2)

  if [[ "${file_type}" != "text/plain" ]]; then
    echo "error: input is not of type: text/plain"

    return 3
  fi

  case "${charset}" in
    "utf-16le" )
      iconv -f utf16le -t utf8 "${input_path}" > "${output_path}" ;;

    * )
      echo "error: unknown charset: ${charset}"

      return 4 ;;
  esac

  return 0
}

function dtbash {
  local session

  if [[ -z "${1}" ]]; then
    echo "error: detach session name missing"
    return 1
  fi

  session="/tmp/${1}.dtach"

  if [[ -e "${session}" ]]; then
    dtach -a "${session}"
  else
    dtach -A "${session}" /bin/bash
  fi
}

function envconfig {
  case "${1}" in
    "wine" )
      export WINEPREFIX="${HOME}/.wine64"
      export WINEARCH=win64 ;;

    * )
      echo "Usage: ${FUNCNAME} wine"
      return 1
  esac
}

function guess_textenc {
  local guesses=(
    "utf16le"
    "gb18030"
    "sjis-open"
  )

  local input_path
  local output_path
  local charset
  local idx
  local guess

  if [[ ! -f "${1}" ]]; then
    echo "error: no such file: ${1}"

    return 1
  fi

  input_path="${1}"

  if [[ -n "${2}" ]]; then
    output_path="${2}"
  else
    output_path="${input_path}.utf8"
  fi

  if [[ -e "${output_path}" ]]; then
    echo "error: output already exists: ${output_path}"

    return 2
  fi

  charset=$(file --brief --mime "${input_path}" | grep -o -E "charset=[[:print:]]+" | cut -d'=' -f2)

  case "${charset}" in
    "utf-8" )
      echo "info: input already has utf-8 encoding"
      cat "${input_path}" > "${output_path}"

      return 0 ;;

    "iso-8859"*|"us-ascii" )
      echo "info: input has encoding: ${charset}"
      iconv -f "${charset}" -t utf8 "${input_path}" > "${output_path}"

      return 0 ;;

     * )
       echo "info: text encoding from MIME inconclusive" ;;
  esac

  idx=0
  while [[ ${idx} -lt ${#guesses[@]} ]]; do
    guess="${guesses[${idx}]}"

    iconv -f "${guess}" -t utf8 "${input_path}" > /dev/null 2> /dev/null

    if [[ $? -eq 0 ]]; then
      echo "info: input has encoding: ${guess}"
      iconv -f "${guess}" -t utf8 "${input_path}" > "${output_path}"

      return 0
    fi

    ((idx++))
  done

  echo "error: failed to detect input encoding"

  return 3
}

function launch_game {
  local target_game
  local gameargs
  local hlargs="-console -nojoy -noipx -novid -noextracds -lw 1920 -lh 1080 -32bpp -freq 144"

  target_game="${1}"
  shift

  case "${target_game}" in
    "--cstrike" )
      if [[ -z "${2}" ]]; then
        echo "error: missing server IP argument"

        return 1
      fi

      gameargs="-game cstrike +exec adminpass.cfg +connect ${2}"

      schedtool -a 0 -e \
      wine "C:\Games\Half-Life\Client\hl.exe" ${hlargs} ${gameargs} ;;

    "--deusex" )
      # Deus Ex has issues with multi-core.
      schedtool -a 0 -e \
      wine "C:\Games\Deus Ex GOTY\System\DeusEx.exe" -localdata -skipdialog ;;

    "--hl" )
      setxkbmap -layout us

      schedtool -a 0 -e \
      wine "C:\Games\Half-Life\Client\hl.exe" ${hlargs}

      setxkbmap -layout de ;;

    "--l4d2" )
      DXVK_CONFIG_FILE="${HOME}/local/dxvk-l4d2.conf" \
      wine start /d "C:\Games\Left 4 Dead 2" "steamclient_loader.exe" ;;

    "--re2" )
      DXVK_CONFIG_FILE="${HOME}/local/dxvk/re2.conf" \
      wine start /d "D:\Games\Resident Evil 2 2019" "re2.exe" ;;

    "--ssam2" )
      wine "C:\Games\Serious Sam 2\Bin\Sam2.exe" ;;

    "--ssamtfe" )
      # Serious Sam: The First Encounter has issues with multi-core.
      # Also force TCP nodelay for any sockets.
      SSAMTFE_NETCFG=1 \
      LD_PRELOAD=${HOME}/local/lib/libnodelay.so \
      schedtool -a 0 -e \
      wine "C:\Program Files\Croteam\Serious Sam\Bin\SeriousSam.exe" ;;

    "--ssamtfe-dedicated" )
      # Dedicated Serious Sam: TFE server
      SSAMTFE_NETCFG=1 \
      LD_PRELOAD=${HOME}/local/lib/libnodelay.so \
      schedtool -a 0 -e \
      wine "C:\Program Files\Croteam\Serious Sam\Bin\DedicatedServer.exe" "$@" ;;

    "--ssamtse" )
      wine "C:\Program Files\Croteam\Serious Sam - The Second Encounter\Bin\SeriousSam.exe" ;;

    "--ut99" )
      PULSE_SERVER=audioserver ${HOME}/HostSystem/Games/UnrealTournament/System/ut-bin ;;

    * )
      echo "Usage: ${FUNCNAME}"
      echo -e "\t --cstrike <server IP>"
      echo -e "\t --deusex [Deus Ex]"
      echo -e "\t --hl [Half-Life (standalone)]"
      echo -e "\t --l4d2 [Left 4 Dead 2]"
      echo -e "\t --re2 [Resident Evil 2 (2019)]"
      echo -e "\t --ssam2 [Serious Sam 2]"
      echo -e "\t --ssamtfe [Serious Sam: The First Encounter]"
      echo -e "\t --ssamtfe-dedicated [Serious Sam dedicated server]"
      echo -e "\t --ssamtse [Serious Sam: The Second Encounter]"
      echo -e "\t --ut99"
       ;;
  esac
}

# File moving with rename:
# - argument 1: source file
# - argument 2: destination directory
# - argument 3: string replacement source
# - argument 4: string replacement destination
function move_rename {
  local source_file
  local destination_directory
  local replacement_source
  local replacement_destination

  local source_base
  local destination

  if [[ ! -f "${1}" ]]; then
    echo "error: source is not a file: ${1}"

    return 1
  fi

  source_file="${1}"

  if [[ ! -d "${2}" ]]; then
    echo "error: destination is not a directory: ${2}"

    return 2
  fi

  destination_directory="${2}"

  if [[ -z "${3}" ]]; then
    echo "error: missing string replacement source"

    return 3
  fi

  replacement_source="${3}"

  if [[ -z "${4}" ]]; then
    echo "error: missing string replacement destination"

    return 4
  fi

  replacement_destination="${4}"

  source_base=$(basename "${source_file}")
  destination="${source_base/${replacement_source}/${replacement_destination}}"

  if [[ -e "${destination_directory}/${destination}" ]]; then
    echo "error: destination already exists: ${destination_directory}/${destination}"

    return 5
  fi

  mv "${source_file}" "${destination_directory}/${destination}"
}

# Convert MSF values to byte indices that can then be feed into shnsplit.
#
# The MSF values can be extracted from the cuesheet file as such:
# grep INDEX <cuesheet> | grep -o -E "[[:digit:]]+:[[:digit:]]+:[[:digit:]]+"
function msf_to_byte {
  local error
  local sample_rate
  local bitrate
  local channels

  local sample_bytes
  local frame_samples
  local minutes
  local seconds
  local frames

  error=0

  while [[ -n "${1}" ]]; do
    case "${1}" in
      "--sample-rate" )
        sample_rate="${2}"
        shift 2 ;;

      "--bitrate" )
        bitrate="${2}"
        shift 2 ;;

      "--channels" )
        channels="${2}"
        shift 2 ;;

      * )
        error=1
        break ;;
    esac
  done

  if [[ ${error} -eq 1 ]] || [[ -z "${sample_rate}" ]] || [[ -z "${bitrate}" ]] || [[ -z "${channels}" ]]; then
    echo "Usage: ${FUNCNAME} --sample-rate <rate in Hz> --bitrate <bits> --channels <number of channels>"

    return 1
  fi

  if [[ $(echo "${bitrate} % 8" | bc) -ne 0 ]]; then
    echo "error: bitrate not a multiple of 8"

    return 2
  fi

  # 1 second = 75 frames
  if [[ $(echo "${sample_rate} % 75" | bc) -ne 0 ]]; then
    echo "error: sample rate not a multiple of 75"

    return 3
  fi

  # sample size in bytes
  sample_bytes=$(echo "(${bitrate} / 8) * ${channels}" | bc)

  # number of samples per frame
  frame_samples=$(echo "${sample_rate} / 75" | bc)

  while read msf_value; do
    minutes=$(echo "${msf_value}" | cut -d':' -f1)
    seconds=$(echo "${msf_value}" | cut -d':' -f2)
    frames=$(echo "${msf_value}" | cut -d':' -f3)

    echo "((${minutes} * 60 + ${seconds}) * ${sample_rate} + ${frames} * ${frame_samples}) * ${sample_bytes}" | bc
  done
}

function permission_sanitize {
  if [[ ! -d "${1}" ]]; then
    return 1
  fi

  find "${1}" -type d -exec chmod 755 {} \;
  find "${1}" -type f -exec chmod 644 {} \;
}

function sbox {
  local sbox_svc="gentoo-sandbox.service"

  local sbox_state

  sbox_state=$(systemctl is-active "${sbox_svc}")
  if [[ "${sbox_state}" != "active" ]]; then
    systemctl start "${sbox_svc}"
  fi

  sudo gentoo_sandbox --enter
}

function sercon_ftdi {
  local device="/dev/ttyFTDI"
  local baudrate="115200"

  if [[ ! -e "${device}" ]]; then
    echo "error: FTDI USB/serial converter not connected"
    return 1
  fi

  screen "${device}" "${baudrate}"
}

function strip_mp4_garbage {
  local garbage="application/octet-stream"
  local bytepos

  if [[ ! -f "${1}" ]]; then
    echo "error: no such file: ${1}"

    return 1
  fi

  if [[ -f "${1}.stripped" ]]; then
    echo "error: stripped version already exists: ${1}.stripped"

    return 2
  fi

  bytepos=$(grep --max-count 1 --only-matching --byte-offset --binary --text "${garbage}" "${1}" | cut -d':' -f1)

  if [[ -z ${bytepos} ]]; then
    echo "error: failed to find garbage position"

    return 3
  fi

  ((bytepos += 28))

  dd if="${1}" of="${1}.stripped" skip="${bytepos}" iflag=skip_bytes
}

function unpack_iso {
  local cdemu_slot=0
  local mount_point="/mnt/optical/virt"

  local iso_file
  local cwd
  local errcode

  cwd=$(pwd)
  iso_file=$(find "${cwd}" -type f -name \*.iso | head --lines=1)

  if [[ -z "${iso_file}" ]]; then
    echo "error: failed to find ISO file"
    return 1
  fi

  echo "info: current working directory: ${cwd}"
  echo "info: unpacking ISO file: ${iso_file}"

  mkdir unpack
  cdemu load ${cdemu_slot} "${iso_file}"
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: failed to load ISO file: ${errcode}"
    return 2
  fi

  mount "${mount_point}"
  errcode=$?

  if [[	${errcode} -ne 0 ]]; then
    echo "error: failed	to mount virtual drive: ${errcode}"
    return 3
  fi

  cp --recursive "${mount_point}"/* unpack/

  umount "${mount_point}"
  cdemu unload ${cdemu_slot}
}

function unpack_multi {
  local rar_part1="part1.rar"
  local rar_part01="part01.rar"

  local unpack_dir
  local unpack_password

  local argbase

  if [[ ! -d "${1}" ]]; then
    echo "error: directory not found: ${1}"

    return 1
  fi

  unpack_dir="${1}"

  if [[ -z "${2}" ]]; then
    echo "error: missing password argument"

    return 2
  fi

  unpack_password="${2}"

  find "${unpack_dir}" -type f -name *.${rar_part1} -or -name *.${rar_part01} | \
  while read arg; do
    argbase="${arg%.${rar_part1}}"
    argbase="${argbase%.${rar_part01}}"

    unrar x -p"${unpack_password}" -inul -- "${arg}" "${1}"/ && rm "${argbase}".part[0-9]*.rar
  done
}

function xmount {
  local mount_point

  if [[ -z "${1}" ]]; then
    echo "error: mount point argument missing"
    return 1
  fi

  if [[ ! -d "${1}" ]]; then
    echo "error: invalid mount point argument"
    return 2
  fi

  mount_point="${1}"

  if mountpoint --quiet "${mount_point}"; then
    echo "info: unmounting ${mount_point}..."
    umount "${mount_point}"
  else
    echo "info: mounting ${mount_point}..."
    mount "${mount_point}"
  fi
}

function xvpn {
  local svc="openvpn-client@client"

  case "${1}" in
    "--start" )
      systemctl start "${svc}" ;;

    "--stop" )
      systemctl stop "${svc}" ;;

    "--status" )
      systemctl status "${svc}" ;;

    * )
      echo "Usage: ${FUNCNAME} --start|--stop|--status"
 
      return 1 ;;
  esac
}
