#!/usr/bin/env bash

zstd -d -c "${1}" | \
tar --extract --file - --preserve-permissions --preserve-order \
  --xattrs-include='*.*' --numeric-owner --directory "${2}"
