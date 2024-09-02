#!/usr/bin/env bash

function kdump_genkernel {
  local genkernel_initrd="/boot/initrd-kdump"

  local genkernel_args=(
    "--config=/etc/kdump/genkernel-config"
    "--no-splash"
    "--no-plymouth"
    "--no-keymap"
    "--no-lvm"
    "--no-mdadm"
    "--no-microcode-initramfs"
    "--no-dmraid"
    "--no-nfs"
    "--no-e2fsprogs"
    "--no-xfsprogs"
    "--no-zfs"
    "--no-btrfs"
    "--no-multipath"
    "--no-iscsi"
    "--no-ssh"
    "--no-luks"
    "--no-gpg"
    "--no-keyctl"
    "--no-b2sum"
    "--no-unionfs"
  )

  local temp_dir
  local errcode

  temp_dir=$(mktemp --directory --quiet)
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: creating temp dir failed: ${errcode}"

    return 1
  fi

  genkernel_args+=("--initramfs-filename=${temp_dir}/initrd")

  genkernel ${genkernel_args[*]} initramfs
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: genkernel failed: ${errcode}"

    return 2
  fi

  if [[ ! -f "${genkernel_initrd}" ]]; then
    echo "error: genkernel-creatred initrd not found"

    return 3
  fi

  pushd "${HOME}"/local/kdump-initrd-extra > /dev/null

  find . -print0 | cpio --quiet --null --create --append --format=newc --owner=0:0 --file="${temp_dir}"/initrd

  popd > /dev/null

  cat "${temp_dir}"/initrd | xz --check=crc32 --lzma2=dict=1MiB -z -c > "${genkernel_initrd}"

  rm "${temp_dir}"/initrd
  rmdir "${temp_dir}"
}

kdump_genkernel "$@"
