project(
  'tjtools',
  ['c', 'cpp'],
  version : '1.0.0',
  default_options : ['warning_level=3']
)


## Common stuff

cc = meson.get_compiler('c')
dep_dl = cc.find_library('dl', required : true)


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

clevo_amp_control_source_files = [
  'src/clevo_amp_control.c',
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

upper_sanitize_source_files = [
  'src/upper_sanitize.cpp',
]

urlparse_source_files = [
  'src/urlparse.cpp',
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

clevo_amp_control = executable(
  'clevo_amp_control',
  clevo_amp_control_source_files,
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
