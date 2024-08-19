# Copyright 1999-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

EGIT_REPO_URI="https://github.com/tobiasjakobi/tjtools.git"

if [[ ${PV} = 9999* ]]; then
	GIT_ECLASS="git-r3"
fi

inherit ${GIT_ECLASS} meson-multilib

DESCRIPTION="Some tools that I use on most of my systems"
HOMEPAGE="https://github.com/tobiasjakobi/tjtools"
KEYWORDS="x86 amd64"
if [[ ${PV} != 9999* ]]; then
	SRC_URI="https://github.com/tobiasjakobi/tjtools/${P}.tar.xz"
fi

LICENSE="GPL-2"
SLOT="0"

RDEPEND=">=acct-user/brightness-0
	>=dev-libs/boost-1.85.0-r1
	>=net-misc/curl-8.8.0-r1
	>=sys-apps/systemd-255.7-r1
	>=virtual/libudev-251-r2"
