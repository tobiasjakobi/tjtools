# Copyright 2020-2024 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

inherit acct-user

ACCT_USER_ID=-1
ACCT_USER_GROUPS=( brightness users )
DESCRIPTION="User for brightness daemon from app-misc/tjtools"

acct-user_add_deps
