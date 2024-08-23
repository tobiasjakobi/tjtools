#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

zstd -d -c "${1}" | \
tar --extract --file - --preserve-permissions --preserve-order \
  --xattrs-include='*.*' --numeric-owner --directory "${2}"
