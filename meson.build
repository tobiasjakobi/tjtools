project(
  'tjtools',
  ['c', 'cpp'],
  version : '1.0.0',
  default_options : ['warning_level=3']
)


## Common stuff

cc = meson.get_compiler('c')
dep_dl = cc.find_library('dl', required : true)

install_prefix = get_option('prefix')
install_bindir = get_option('bindir')

systemd = dependency('systemd')
systemd_system_unit_dir = systemd.get_variable('systemdsystemunitdir')

udev = dependency('udev')
udev_rules_dir = udev.get_variable('udev_dir') / 'rules.d'

polkit = dependency('polkit-gobject-1')
polkit_rules_dir = polkit.get_variable('policydir') / '../rules.d'

conf = configuration_data()


## Source files and dependencies

access_blocker_source_files = [
  'src/access_blocker.c',
]

access_blocker_dependencies = [
  dep_dl,
]

access_blocker_soversion = 1

active_user_source_files = [
  'src/active_user.c',
]

active_user_dependencies = [
  dependency('libsystemd'),
]

active_user_soversion = 1

awinic_detect_source_files = [
  'src/awinic_detect.c',
]

awinic_detect_dependencies = [
  cc.find_library('libi2c', required : true),
]

brightness_daemon_source_files = [
  'src/brightness_utils/common.cpp',
  'src/brightness_daemon.cpp',
]

brightness_daemon_dependencies = [
  dependency('libsystemd'),
]

clevo_amp_control_source_files = [
  'src/clevo_amp_control.c',
]

container_source_files = [
  'src/container.cpp',
]

container_dependencies = [
  dependency('boost', modules : ['program_options']),
  dependency('fmt'),
  dependency('libcurl'),
]

evdev_keepalive_source_files = [
  'src/evdev_keepalive.c',
]

notify_wrapper_source_files = [
  'src/notify_wrapper.c',
]

notify_wrapper_dependencies = [
  dependency('libsystemd'),
]

battery_watch_source_files = [
  'src/battery_watch.cpp',
]

battery_watch_dependencies = [
  dependency('boost', modules : ['program_options']),
  dependency('libudev'),
]

cpu_powerlimit_source_files = [
  'src/cpu_powerlimit.cpp'
]

cpu_powerlimit_dependencies = [
  dependency('boost', modules : ['program_options']),
]

speedcontrolpp_source_files = [
  'src/speedcontrolpp.cpp'
]

speedcontrolpp_dependencies = [
  dependency('boost', modules : ['program_options']),
]

upper_sanitize_source_files = [
  'src/upper_sanitize.cpp',
]

urlparse_source_files = [
  'src/urlparse.cpp',
]


## systemd unit files

unit_files = [
  'battery-watch.service',
  'brightness-daemon.service',
  'cpu-powerlimit@.service',
  'gentoo-sandbox.service',
  'iscsi-ctrl@.service',
  'mnt-blackHole.mount',
  'mnt-universe.mount',
  'razer-config@.service',
  'unlock-container@.service',
  'xbox360-config@.service',
  'xbox360-disable.service',
]


## UDev rules

udev_rules = [
  '10-external-input.rules',
  '11-razer-mouse.rules',
  '12-serial-ir.rules',
  '51-rfkill.rules',
  '61-android-phone.rules',
  '61-drm-amdgpu.rules',
  '61-optical-drives.rules',
  '61-usb-serial.rules',
  '70-gamepad-controller.rules',
  '80-docked-mode.rules',
  '91-fiio-bta30pro.rules',
]


## PolicyKit rules

polkit_rules = [
  '10-gentoo-sandbox.rules',
  '11-openvpn-client.rules',
  '12-iscsi-ctrl.rules',
  '13-cpu-powerlimit-quiet.rules',
]


## Build arguments

library_build_args = [
  '-DTJTOOLS_PUBLIC=__attribute__((visibility("default")))'
]


## Targets

access_blocker = shared_library(
  'access_blocker',
  access_blocker_source_files,
  dependencies: access_blocker_dependencies,
  install : true,
  version : meson.project_version(),
  soversion : access_blocker_soversion,
  c_args : library_build_args,
  gnu_symbol_visibility : 'hidden',
)

active_user = shared_library(
  'active_user',
  active_user_source_files,
  dependencies: active_user_dependencies,
  install : true,
  version : meson.project_version(),
  soversion : active_user_soversion,
  c_args : library_build_args,
  gnu_symbol_visibility : 'hidden',
)

awinic_detect = executable(
  'awinic_detect',
  awinic_detect_source_files,
  dependencies : awinic_detect_dependencies,
  install : true,
)

brightness_daemon = executable(
  'brightness_daemon',
  brightness_daemon_source_files,
  dependencies : brightness_daemon_dependencies,
  install : true,
)

clevo_amp_control = executable(
  'clevo_amp_control',
  clevo_amp_control_source_files,
  install : true,
)

container = executable(
  'container',
  container_source_files,
  dependencies : container_dependencies,
  install : true,
)

evdev_keepalive = executable(
  'evdev_keepalive',
  evdev_keepalive_source_files,
  install : true,
)

notify_wrapper = executable(
  'notify_wrapper',
  notify_wrapper_source_files,
  dependencies : notify_wrapper_dependencies,
  install : true,
)

battery_watch = executable(
  'battery_watch',
  battery_watch_source_files,
  dependencies : battery_watch_dependencies,
  install : true,
)

cpu_powerlimit = executable(
  'cpu_powerlimit',
  cpu_powerlimit_source_files,
  dependencies : cpu_powerlimit_dependencies,
  install : true,
)

speedcontrolpp = executable(
  'speedcontrolpp',
  speedcontrolpp_source_files,
  dependencies : speedcontrolpp_dependencies,
  install : true,
)

upper_sanitize = executable(
  'upper_sanitize',
  upper_sanitize_source_files,
  install : true,
)

urlparse = executable(
  'urlparse',
  urlparse_source_files,
  install : true,
)

install_data(
  'scripts/fstrim_gen_env.sh',
  install_mode : 'rwxr-xr-x',
  install_dir : install_prefix / install_bindir
)

scripts = [
  '7z_simple.sh',
  'backup_bootstrap.sh',
  'build_old_samba.sh',
  'copy_merge.sh',
  'detect_display.sh',
  'easy_pack.sh',
  'easy_unpack.sh',
  'exec_script.sh',
  'flatpak_env_helper.sh',
  'fstrim_gen_env.sh',
  'gamescope-session',
  'geeqie_ctrl.sh',
  'greetd-session',
  'iscsi_ctrl.sh',
  'linux_maintainers.sh',
  'net_ps2.sh',
  'pinentry.sh',
  'remount_storage.sh',
  'resume_wrapper.sh',
  'session_helper.sh',
  'steam-gamepadui-session',
  'steamos-session-select',
  'sway-session',
  'sysfs_write.sh',
]

foreach s : scripts
  install_data(
    'scripts' / s,
    install_mode : 'rwxr-xr-x',
    install_dir : install_prefix / install_bindir
  )
endforeach

foreach u : unit_files
  install_data(
    'systemd' / u,
    install_mode : 'rw-r--r--',
    install_dir : systemd_system_unit_dir,
  )
endforeach

foreach r : udev_rules
  install_data(
    'udev' / r,
    install_mode : 'rw-r--r--',
    install_dir : udev_rules_dir,
  )
endforeach

foreach r : polkit_rules
  install_data(
    'polkit' / r,
    install_mode : 'rw-r--r--',
    install_dir : polkit_rules_dir,
  )
endforeach
