#!/usr/bin/env bash

function sway_appmenu {
  local font="Liberation Sans 16"
  local white="#ffffff"
  local black="#000000"
  local green="#14d711"

  bemenu -i --fn "${font}" --prompt="Choose application:" \
    --tb=${white} --tf=${black} --nf=${green} --nb=${black} \
    --hf=${black} --hb=${green} --monitor="all"
}

sway_appmenu "$@"
