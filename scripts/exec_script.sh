#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

source ${HOME}/.bashrc.extern

scriptcmd="${1}"
shift

${scriptcmd} "$@"
