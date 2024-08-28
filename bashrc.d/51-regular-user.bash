function __vnc_internal {
  local vnc_host
  local vnc_username
  local vnc_password

  vnc_host="${1}"
  vnc_username="${2}"
  vnc_password="${3}"

  case "${1}" in
    "--spawn" )
      ssh -L 15900:localhost:5900 "${vnc_host}" "env WAYLAND_DISPLAY=wayland-1 wayvnc --keyboard=de-nodeadkeys --render-cursor --gpu 127.0.0.1 5900" ;;

    "--connect" )
      env VNC_USERNAME="${vnc_username}" VNC_PASSWORD="${vnc_password}" vncviewer localhost::15900 ;;

    "--exit" )
      ssh "${vnc_host}" "wayvncctl wayvnc-exit" ;;

    * )
      echo "Usage: ${FUNCNAME} --spawn|--connect|--exit" ;;
  esac
}

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
