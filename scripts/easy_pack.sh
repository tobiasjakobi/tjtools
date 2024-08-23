#!/usr/bin/env bash

tar --create --file - --preserve-permissions --xattrs-include='*.*' \
  --numeric-owner --directory="${1}" ./ | zstd -z -12 -o "${2}"
