# Bash functions mainly intended for the superuser of the system.

## Helpers

function print_stderr {
  >&2 echo "$@"
}

function __get_kernel_version {
  local dir_prefix="linux-"

  local cwd
  local dir_path
  local ver_string
  local ver_semantic

  cwd=$(realpath $(pwd))
  dir_path=$(basename "${cwd}")

  if [[ "${dir_path:0:6}" != "${dir_prefix}" ]]; then
    return 1
  fi

  ver_string=$(echo ${dir_path#${dir_prefix}} | cut -d- -f1)

  readarray -t -d . ver_semantic < <(echo "${ver_string}")

  echo -n "${ver_semantic[0]}.${ver_semantic[1]}"
}

## Bash functions

function filesystem_backup {
  local mode

  local operation_file
  local operation_directory

  if [[ -z "${1}" ]]; then
    print_stderr "error: backup filename missing"
    return 1
  fi

  operation_file="${1}"

  if [[ -f "${operation_file}" ]]; then
    mode="unpack"
  elif [[ "${operation_file}" == "stdin" ]]; then
    mode="unpack"
    operation_file="-"
  elif [[ "${operation_file}" == "stdout" ]]; then
    mode="pack"
    operation_file="-"
  else
    mode="pack"
  fi

  if [[ ! -d "${2}" ]]; then
    print_stderr "error: not a directory: ${2}"
    return 2
  fi

  operation_directory="${2}"

  case "${mode}" in
    pack )
      print_stderr "info: packing from \"${operation_directory}\" to \"${operation_file}\""
      tar --create --file "${operation_file}" --preserve-permissions --xattrs-include='*.*' \
          --numeric-owner --directory "${operation_directory}" ./ ;;

    unpack )
      print_stderr "info: unpacking to \"${operation_directory}\" from \"${operation_file}\""
      tar --extract --file "${operation_file}" --preserve-permissions --preserve-order \
          --xattrs-include='*.*' --numeric-owner --directory "${operation_directory}" ;;
  esac
}

function full_upd {
  emerge --update --deep --newuse "$@" @world
}

# kernel make wrapper
function kmake {
  local kernel_ver
  local config_name
  local build_ver
  local errocde

  kernel_ver=$(__get_kernel_version)
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: failed to get kernel version: ${errcode}"

    return 1
  fi

  echo "info: detected kernel version: ${kernel_ver}"

  if [[ -e ./".config" ]]; then
    mv ./".config" ./".config.backup"
  fi

  config_name="vanilla-${kernel_ver}.conf"

  echo "info: using config: ${config_name}"

  cp ../"${config_name}" ./".config"

  if [[ -n "${1}" ]]; then
    make "${1}"
  fi

  make -j8 && make modules_install
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: kernel make or module make failed: ${errcode}"

    return 2
  fi

  cp ./".config" ../"${config_name}"

  # extract version from kernel header
  build_ver=$(grep UTS_RELEASE include/generated/utsrelease.h | cut -d\" -f2)
  if [[ -z "${build_ver}" ]]; then
    echo "error: failed to extract kernel version"

    return 3
  fi

  cp arch/x86/boot/bzImage /boot/kernel-${build_ver}
  ln -sf initrd-common /boot/initrd-${build_ver}
}

# crashkernel make wrapper
function kmake_kdump {
  local kernel_ver
  local errcode

  kernel_ver=$(__get_kernel_version)
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: failed to get kernel version: ${errcode}"

    return 1
  fi

  echo "info: detected kernel version: ${kernel_ver}"

  if [[ -e ./".config" ]]; then
    mv ./".config" ./".config.backup"
  fi

  config_name="vanilla-${kernel_ver}.kdump.conf"

  echo "info: using config: ${config_name}"

  cp ../"${config_name}" ./".config"

  if [[ -n "${1}" ]]; then
    make "${1}"
  fi

  make -j8
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: kernel make failed: ${errcode}"

    return 2
  fi

  cp ./".config" ../"${config_name}"

  # extract version from kernel header
  build_ver=$(grep UTS_RELEASE include/generated/utsrelease.h | cut -d\" -f2)
  if [[ -z "${build_ver}" ]]; then
    echo "error: failed to extract kernel version"

    return 3
  fi

  cp arch/x86/boot/bzImage /boot/kdump-${build_ver}
}

# apply local kernel patches to the tree
function kpatch_apply {
  local patchdir="/usr/src/kernel_patches"

  find "${patchdir}" -type f -name \*.patch | sort -n | \
  while read patch; do
    git apply --stat --apply "${patch}"
  done
}

function kpatch_copy {
  local src="/home/liquid/development/linux-kernel"
  local dst="/usr/src/kernel_patches"

  rm -f ${dst}/*.patch

  find ${src} -maxdepth 1 -type f -name \*.patch | \
  while read arg; do
    cp ${arg} ${dst}/
  done

  chmod 644 ${dst}/*.patch
}

function light_upd {
  emerge --update --deep --newuse --exclude="www-client/chromium" --exclude="www-client/firefox" \
    --exclude="app-office/libreoffice" "$@" @world
}

function net_config {
  local ethernet="enp5s0"
  local prefix="/etc/systemd/network"
  local name="20-ethernet"
  local smb_manage="/usr/local/samba/bin/manage.sh"

  local mode
  local errcode

  case "${1}" in
    "--dhcp" )
      mode="dhcp" ;;

    "--ps2" )
      mode="ps2" ;;

    * )
      echo -e "Usage: ${FUNCNAME}"
      echo -e "\t --dhcp [use DHCP for Ethernet interface]"
      echo -e "\t --ps2 [special fixed IP setup for PS2]"

      return 1 ;;
  esac

  if [[ "${mode}" = "ps2" ]]; then
    ln -sf "${name}.link-ps2" "${prefix}/${name}.link"
    ln -sf "ps2-fixed" "${prefix}/${name}.network.d/active.conf"
  else
    rm "${prefix}/${name}.link"
    ln -sf "dhcp" "${prefix}/${name}.network.d/active.conf"
  fi

  networkctl reload
  networkctl reconfigure "${ethernet}"

  if [[ "${mode}" = "ps2" ]]; then
    ${smb_manage} --start
    net_ps2.sh "${ethernet}"
    ${smb_manage} --stop
  fi
}

function sercon {
  local tty="/dev/ttyUSB0"

  if [[ -c "${tty}" ]]; then
    screen "${tty}" 115200
  fi
}
