#!/usr/bin/env bash

tar --create --file - --preserve-permissions --xattrs-include='*.*' \
    --numeric-owner --directory "${1}" ./ | pv | nc -q 5 -l -p 12345
