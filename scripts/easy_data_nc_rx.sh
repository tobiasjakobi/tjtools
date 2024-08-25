#!/usr/bin/env bash

nc -q 5 "${1}" 12345 | \
tar --extract --file - --preserve-permissions --preserve-order \
    --xattrs-include='*.*' --numeric-owner --directory "${2}"
