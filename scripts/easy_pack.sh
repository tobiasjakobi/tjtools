#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

tar --create --file - --preserve-permissions --xattrs-include='*.*' \
  --numeric-owner --directory="${1}" ./ | zstd -z -12 -o "${2}"
