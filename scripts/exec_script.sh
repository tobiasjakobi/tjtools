#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

source ${HOME}/.bashrc.extern

for _ in /etc/bash/bashrc.d/50-*; do
  if [[ $_ == *.@(bash|sh) && -r $_ ]]; then
    source "$_"
  fi
done

scriptcmd="${1}"
shift

${scriptcmd} "$@"
