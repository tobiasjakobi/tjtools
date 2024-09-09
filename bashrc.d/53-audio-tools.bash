# Bash functions for handling of audio files.

function clean_audiofiles {
  local bad_tags=(
    "album artist"
    "albumartist"
    "compilation"
    "contentgroup"
    "copyright"
    "description"
    "label"
    "totaldiscs"
    "totaltracks"
    "waveformatextensible_channel_mask"
  )

  if [[ -n "${1}" ]]; then
    while [[ -n "${1}" ]]; do
      echo "info: cleaning: ${1}"

      for arg in *.flac; do
        vc_cleantags "${arg}" "${1}"
      done

      shift
    done
  else
    for arg in *.flac; do
      vc_cleantags "${arg}" ${bad_tags[*]}
    done
  fi
}

function encoding_postfix {
  local encodings=(
    'FLAC'
    'Vorbis'
    'AAC'
    'VBR V[[:digit:]]+'
    'CBR [[:digit:]]+'
  )

  local idx
  local test_enc

  idx=0

  while [[ ${idx} -lt ${#encodings[*]} ]]; do
    test_enc=" \(${encodings[${idx}]}\)$"
    echo "${1}" | grep --only-matching --extended-regexp "${test_enc}"

    ((idx++))
  done
}

# Create a M3U playlist file for a directory containing audio files.
function m3u_create {
  local working_dir

  local files
  local first_file
  local prefix
  local directory_name
  local postfix
  local m3u_base

  if [[ -z "${1}" ]]; then
    echo "Usage: ${FUNCNAME} <directory>"

    return 0
  fi

  if [[ ! -d "${1}" ]]; then
    echo "error: directory not found: ${1}"

    return 1
  fi

  working_dir=$(realpath "${1}")

  if [[ -n "$(ls "${working_dir}"/*.m3u 2> /dev/null)" ]]; then
    echo "error: directory already contains an M3U"

    return 2
  fi

  # Create list of audio files with known extension.
  files=$(find "${working_dir}" -type f -regextype posix-egrep -regex '.+[[:digit:]]+ .+\.(flac|mp3|ogg|m4a)' | sort)

  if [[ -z "${files}" ]]; then
    echo "error: no audio files found in: ${1}"

    return 3
  fi

  first_file=$(echo "${files}" | head -n 1)

  case "$(basename "${first_file}")" in
    "01 "* )
      prefix="00" ;;

    "001"* )
      prefix="000" ;;

    "101"* )
      prefix="000" ;;

    "1001"* )
      prefix="0000" ;;

    * )
      echo "error: cannot determine M3U prefix"

      return 4 ;;
  esac

  directory_name=$(basename "${working_dir}")

  # Find the postfix ("(FLAC)", "(Vorbis)", etc.) of the directory name.
  postfix=$(encoding_postfix "${directory_name}")

  # Strip the postfix and create M3U base.
  m3u_base=${directory_name%"${pathpostfix}"}

  echo "${filelist}" | while read line; do
    basename "${line}"
  done > "${working_dir}/${prefix} ${m3u_base}.m3u"

  echo "${prefix} ${m3u_base}"
}
