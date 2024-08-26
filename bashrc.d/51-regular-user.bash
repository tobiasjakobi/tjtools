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
    cmd="systemctl --user stop pulse-bs2b@default pulse-bs2b@chu-moy pulse-bs2b@jan-meier"
  else
    cmd="systemctl --user start pulse-bs2b@${profile}"
  fi

  echo "${cmd}" | ssh audioserver "bash -s"
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
