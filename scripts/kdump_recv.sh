#!/usr/bin/env bash

function kdump_recv {
  local dmp_prefix="${HOME}/local/kdump-storage/kdump"

  xz --quiet --compress -8 --stdout - > ${dmp_prefix}-$(date +%s).dmp.xz
}

kdump_recv "$@"
