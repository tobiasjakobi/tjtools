#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

function __pinentry {
  local font="Liberation Sans 22"

  local white="#ffffff"
  local black="#000000"
  local green="#14d711"

  pinentry-bemenu --center --fn="${font}" --monitor="focused" "$@"
}

__pinentry "$@"
