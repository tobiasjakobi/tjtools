function full_upd {
  emerge -uDN "$@" @world
}

function light_upd {
  emerge -uDN --exclude="www-client/chromium" --exclude="www-client/firefox" --exclude="app-office/libreoffice" "$@" @world
}

function sercon {
  local tty="/dev/ttyUSB0"

  [[ -c "${tty}" ]] && screen "${tty}" 115200
}

function net_config {
  local ethernet="enp5s0"
  local prefix="/etc/systemd/network"
  local name="20-ethernet"

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
    /usr/local/samba/bin/manage.sh --start
    "${HOME}"/local/bin/net_ps2.sh "${ethernet}"
    /usr/local/samba/bin/manage.sh --stop
  fi
}

# apply local kernel patches to the tree
function kpatch {
  local patchdir="/usr/src/kernel_patches"

  find "${patchdir}" -type f -name \*.patch | sort -n | \
  while read patch; do
    git apply --stat --apply "${patch}"
  done
}

# kernel make wrapper
function kmake {
  local version

  [[ -n "${1}" ]] && make "${1}"

  make -j8 && make modules_install
  if [ $? -ne 0 ]; then
    echo "error: kernel make or module make failed"
    return 2
  fi

  # extract version from kernel header
  version=$(grep UTS_RELEASE include/generated/utsrelease.h | cut -d\" -f2)
  if [ -z "${version}" ]; then
    echo "error: failed to extract kernel version"
    return 3
  fi

  cp arch/x86/boot/bzImage /boot/kernel-${version}
  ln -sf initrd-common /boot/initrd-${version}
}

function filesystem_backup {
  local mode

  if [ -z "${1}" ]; then
    echo "error: backup filename missing"
    return 1
  fi

  if [ -f "${1}" ]; then
    mode="unpack"
  else
    mode="pack"
  fi

  if [ ! -d "${2}" ]; then
    echo "error: \"${2}\" is not a directory"
    return 2
  fi

  case "${mode}" in
    pack )
      echo "info: packing from \"${2}\" to \"${1}\""
      tar --create --file "${1}" --preserve-permissions --xattrs-include='*.*' \
          --numeric-owner --directory "${2}" ./ ;;

    unpack )
      echo "info: unpacking to \"${2}\" from \"${1}\""
      tar --extract --file "${1}" --preserve-permissions --preserve-order \
          --xattrs-include='*.*' --numeric-owner --directory "${2}" ;;
  esac
}
