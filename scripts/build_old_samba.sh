#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

set -e

function build_old_samba {
  local samba_prefix=/usr/local/samba
  local samba_tar="samba-3.6.25.tar.gz"
  local samba_url="https://download.samba.org/pub/samba/stable"
  local samba_sha="25a5c56dae4517e82e196b59fa301b661ec75db57effbb0ede35fb23b018f78cdea6513e8760966caf58abc43335fcebda77fe5bf5bb9d4b27fd3ca6e5a3b626"

  if [[ ! -f /usr/distfiles/"${samba_tar}" ]]; then
    wget --output-document=/usr/distfiles/"${samba_tar}" "${samba_url}"/"${samba_tar}"
  fi

  sha=$(sha512sum /usr/distfiles/"${samba_tar}" | cut -d' ' -f1)

  if [[ "${sha}" != "${samba_sha}" ]]; then
    echo "error: SHA verification failed"

    return 1
  fi

  tmpdir=$(mktemp --directory)

  tar --extract --file=/usr/distfiles/"${samba_tar}" --directory="${tmpdir}"

  source "${HOME}"/local/build.environment

  pushd "${tmpdir}"/samba-3.6.25/source3

  ./configure --prefix="${samba_prefix}"/ \
    --with-piddir="${samba_prefix}"/run/ \
    --sysconfdir="${samba_prefix}"/etc/ \
    --localstatedir="${samba_prefix}"/var \
    --enable-largefile \
    --disable-iprint \
    --disable-fam \
    --enable-shared-libs \
    --disable-external-libtalloc \
    --disable-external-libtevent \
    --disable-external-libtdb \
    --disable-dnssd \
    --disable-avahi \
    --disable-swat \
    --with-fhs \
    --with-privatedir="${samba_prefix}"/private \
    --with-rootsbindir="${samba_prefix}"/cache \
    --with-lockdir="${samba_prefix}"/cache \
    --with-configdir="${samba_prefix}"/etc \
    --with-logfilebase="${samba_prefix}"/log \
    --without-dmapi \
    --without-vfs-afsacl \
    --without-pam \
    --without-syslog \
    --without-utmp \
    --without-libnetapi \
    --without-libsmbclient \
    --without-libaddns \
    --without-acl-support \
    --with-aio-support \
    --without-sendfile-support \
    --without-winbind

  make -j5 bin/{smbd,nmbd,smbpasswd}

  cp --preserve=all --no-dereference bin/{smbd,nmbd,smbpasswd} /usr/local/samba/bin/
  cp --preserve=all --no-dereference bin/libt{alloc,db,event}.so* /usr/local/samba/lib/

  popd

  rm --recursive --force "${tmpdir}"/samba-3.6.25
  rmdir "${tmpdir}"
}

build_old_samba "$@"
