#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

function linux_maintainers {
  local repo="${HOME}/development/linux-kernel"

  local patch_base

  if [[ -f "${2}" ]]; then
    patch_base=$(basename "${2}")

    if [[ "${patch_base}" == "0000-cover-letter.patch" ]]; then
      return 0
    fi
  fi

  "${repo}/scripts/get_maintainer.pl" --nogit --nogit-fallback --norolestats "$@"
}

linux_maintainers "$@"
