# Bash functions for handling of audio files.

# Package a directory containing a (lossless) album rip.
function album_package {
  local working_dir

  local archive_prefix
  local errcode

  if [[ -z "${1}" ]]; then
    echo "Usage: ${FUNCNAME} <directory>"

    return 0
  fi

  if [[ ! -d "${1}" ]]; then
    echo "error: directory not found: ${1}"

    return 1
  fi

  working_dir="${1}"

  archive_prefix=$(m3u_create "${working_dir}")
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: creating M3U for directory failed: ${working_dir}: ${errcode}"

    return 2
  fi

  find "${working_dir}" -maxdepth 1 -type d -regextype posix-egrep -regex '.+/(Scans|Infos|Artwork|Scans\+Infos|Artwork\+Infos)' | \
  while read arg; do
    7z_simple.sh --location="${working_dir}" --prefix="${archive_prefix} " "${arg}" > /dev/null && rm --force --recursive "${arg}"
  done

  checksum --sha-scan "${working_dir}"
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: creating SHA for directory failed: ${working_dir}: ${errcode}"

    return 3
  fi
}

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

# Sanitize ExactAudioCopy's cuesheets and logfile.
function eac_sanitize {
  local cwd
  local tempdir
  local directory_name
  local postfix
  local extension
  local file_base
  local out_type
  local counter

  cwd=$(realpath ${PWD})

  mkdir "${cwd}"/Infos
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: failed to create Infos directory: ${errcode}"

    return 1
  fi

  tempdir=$(mktemp --directory --tmpdir=/dev/shm/)
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: failed to create temporary directory: ${errcode}"

    return 2
  fi

  directory_name=$(basename "${cwd}")

  # TODO: Fix this for disc indices >= 10.
  case "${directory_name}" in
    "disc"[1-9] )
      postfix=" Disc ${directory_name:4}" ;;

    * )
      postfix="" ;;
  esac

  find "${cwd}" -type f -name \*.log -or -name \*.cue | \
  while read arg; do
    extension=$(get_fileext "${arg}")

    case "${extension}" in
      "log" )
        convert_textenc "${arg}" "${tempdir}"/log && \
          strip_utf8bom "${tempdir}"/log "${tempdir}"/log1 && \
          convert_crlf "${tempdir}"/log1 Infos/"00 Logfile${postfix}.log" && \
          rm "${tempdir}"/{log,log1} ;;

      "cue" )
        iconv -f iso-8859-1 -t utf8 "${arg}" > "${tempdir}"/cue && \
          convert_crlf "${tempdir}"/cue "${tempdir}"/cue1 && \
          rm "${tempdir}"/cue

        file_base=$(basename "${arg}" ".${extension}")

        case "${file_base}" in
          "single" )
            out_type="Single File" ;;

          "noncompl" )
            out_type="Noncompliant" ;;

          * )
            out_type="" ;;
        esac

        # If the cuesheet type cannot be detected, just choose a
        # generic filename. Make sure that the file doesn't exist.
        if [[ -z "${out_type}" ]]; then
          counter=1

          while true; do
            if [[ -e Infos/"00 Cuesheet${postfix} (Raw, Unknown${counter}).cue" ]]; then
              ((counter++))
            else
              out_type="Unknown${counter}"
              break
            fi
          done
        fi

        cp "${tempdir}"/cue1 Infos/"00 Cuesheet${postfix} (Raw, ${out_type}).cue" &&
        rm "${tempdir}"/cue1 ;;

      * )
        echo "error: unknown extension \"${extension}\" encountered"

        return 1 ;;
    esac
  done

  rmdir "${tempdir}"
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

function rip_sanitize {
  local working_dir
  local tempdir
  local errcode

  if [[ ! -d "${1}" ]]; then
    echo "error: no such directory: ${1}"

    return 1
  fi

  working_dir="${1}"

  tempdir=$(mktemp --directory --tmpdir=/dev/shm/)
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: failed to crete temporary directory: ${errcode}"

    return 2
  fi

  find "${working_dir}" -type f -iname \*.log -or -iname \*.cue | while read arg; do
    guess_textenc "${arg}" "${tempdir}"/out.utf8 && \
      strip_utf8bom "${tempdir}"/out.utf8 "${tempdir}"/out.noBOM && \
      convert_crlf "${tempdir}"/out.noBOM "${tempdir}"/out.crlf

    errcode=$?

    if [[ ${errcode} -eq 0 ]]; then
      mv "${tempdir}"/out.crlf "${arg}"
    else
      echo "warn: no valid encoding found: skipping ${arg}: ${errcode}"
    fi

    rm --force "${tempdir}"/out.utf8 "${tempdir}"/out.noBOM "${tempdir}"/out.crlf
  done

  rmdir "${tempdir}"
}
