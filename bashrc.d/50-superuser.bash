function full_upd {
  emerge --update --deep --newuse "$@" @world
}

function light_upd {
  emerge --update --deep --newuse --exclude="www-client/chromium" --exclude="www-client/firefox" \
    --exclude="app-office/libreoffice" "$@" @world
}

function sercon {
  local tty="/dev/ttyUSB0"

  if [[ -c "${tty}" ]]; then
    screen "${tty}" 115200
  fi
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

# kernel make wrapper
function kmake {
  local version
  local errocde

  if [[ -n "${1}" ]]; then
    make "${1}"
  fi

  make -j8 && make modules_install
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: kernel make or module make failed: {errcode}"

    return 2
  fi

  # extract version from kernel header
  version=$(grep UTS_RELEASE include/generated/utsrelease.h | cut -d\" -f2)
  if [[ -z "${version}" ]]; then
    echo "error: failed to extract kernel version"

    return 3
  fi

  cp arch/x86/boot/bzImage /boot/kernel-${version}
  ln -sf initrd-common /boot/initrd-${version}
}

function filesystem_backup {
  local mode

  if [[ -z "${1}" ]]; then
    echo "error: backup filename missing"

    return 1
  fi

  if [[ -f "${1}" ]]; then
    mode="unpack"
  else
    mode="pack"
  fi

  if [[ ! -d "${2}" ]]; then
    echo "error: not a directory: {2}"

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
