# Bash functions just are thin wrappers around other functions, CLI tools, application, etc.

function albion {
  ${HOME}/local/bin/dosbox.py ${HOME}/Games/albion/dosbox.conf
}

function audioserver_openvpn {
  ssh -t audioserver "sudo openvpn.sh $@"
}

function audioserver_pavucontrol {
  pkill --exact pavucontrol
  PULSE_SERVER=audioserver pavucontrol
}

function audioserver_poweroff {
  ssh audioserver "sudo systemctl poweroff"
}

function audioserver_pulse {
  export PULSE_SERVER=tcp4:audioserver.entropy
}

function chromium_proxy {
  chromium --proxy-server="socks5://localhost:12557" --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE localhost"
}

function clksrc {
  cat /sys/devices/system/clocksource/clocksource0/current_clocksource
}

# Returns the free space in bytes on a given filesystem.
function filesystem_free_space {
  if [[ -z "${1}" ]]; then
    return
  fi

  stat --file-system --printf="%a * %s\n" "${1}" | bc
}

# Return the extension of a filename.
function get_fileext {
  if [[ -z "${1}" ]]; then
    return
  fi

  echo "${1##*.}"
}

# Output nicely formatted MPD "Now Playing" status.
function mpc_status {
  mpc --format="%artist% - [\[%album%\] ]%title%" current
}

function notes {
  scite -loadsession:${HOME}/local/notes.session
}

function onyx_poweroff {
  ssh onyx "sudo systemctl poweroff"
}

function qt_duckstation {
  local cfg=$(cat ${HOME}/local/xpadneo-sdl.conf)

  SDL_JOYSTICK_HIDAPI=0 SDL_GAMECONTROLLERCONFIG="${cfg}" PULSE_SERVER=audioserver duckstation-qt
}

function qt_higan {
  PULSE_SERVER=audioserver QT_QPA_PLATFORM=xcb higan
}

function qt_mgba {
  local cfg=$(cat ${HOME}/local/xpadneo-sdl.conf)

  SDL_JOYSTICK_HIDAPI=0 SDL_GAMECONTROLLERCONFIG="${cfg}" PULSE_SERVER=audioserver QT_QPA_PLATFORM=xcb mgba-qt
}

function qt_yuzu {
  PULSE_SERVER=audioserver QT_QPA_PLATFORM=xcb yuzu
}

function space3 {
  ${HOME}/local/bin/dosbox.py ${HOME}/Games/space3/dosbox.conf
}

