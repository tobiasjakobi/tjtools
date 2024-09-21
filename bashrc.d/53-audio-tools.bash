# Bash functions for handling of audio files.

## Helpers

function __decode_to_pcm_wav {
  local input_file
  local tmp_dir

  local errcode
  local needs_decoding
  local codec

  input_file="${1}"
  tmp_dir="${2}"

  needs_decoding=0

  source "${HOME}"/local/bin/mpv_identify.sh id_ "${input_file}"
  codec=$(echo "${id_audio_codec_name}" | cut -d' ' -f1)

  case "${codec}" in
    "pcm_s16le" )
      ln --symbolic "${input_file}" "${tmp_dir}"/input.wav
      echo "info: input file has WAVE (PCM, s16le) format" ;;

    "flac" )
      echo "info: input file has FLAC format"
      needs_decoding=1 ;;

    "tta" )
      echo "info: input file has TTA (True Audio) format"
      needs_decoding=1 ;;

    "tak" )
      echo "info: input file has TAK format"
      needs_decoding=1 ;;

    "ape" )
      echo "info: input file has APE (Monkey's Audio) format"
      needs_decoding=1 ;;

    "alac" )
      echo "info: input file has M4A/ALAC format"
      needs_decoding=1 ;;

    "wavpack" )
      echo "info: input file has WavPack format"
      needs_decoding=1 ;;

    * )
      echo "error: unknown input format: ${id_audio_codec_name}"

      return 1 ;;
  esac

  if [[ ${needs_decoding} -eq 1 ]]; then
    ffmpeg -i "${input_file}" -loglevel warning "${tmp_dir}"/input.wav
  fi

  errcode=$?
  if [[ ${errcode} -ne 0 ]]; then
    echo "error: input decoding failed: ${errcode}"

    return 2
  fi

  return 0
}

function __cuesheet_to_splitpoints {
  local cuesheet="${1}"

  cuebreakpoints --input-format cue --append-gaps "${cuesheet}"
}

function __cuesheet_check {
  local cuesheet_file="${1}"

  local cuesheet_info
  local cuesheet_type
  local cuesheet_encoding
  local errcode

  cuesheet_info=$(file --dereference --brief --mime "${cuesheet_file}")

  cuesheet_type=$(echo "${cuesheet_info}" | cut -d';' -f1)

  if [[ "${cuesheet_type}" != "text/plain" ]]; then
    echo "error: cuesheet not a text file: ${cuesheet_file}"

    return 1
  fi

  cuesheet_encoding=$(echo "${cuesheet_info}" | cut -d';' -f2 | cut -d'=' -f2)

  # Check the text encoding of the cuesheet first.
  # cuebreakpoints chokes on non-utf8 / ascii encodings.
  case "${cuesheet_encoding}" in
    "utf-8" )
      echo "info: cuesheet has utf-8 encoding" ;;

    "us-ascii" )
      echo "info: cuesheet has us-ascii encoding" ;;

    * )
      echo "error: unknown cuesheet encoding: ${cuesheet_encoding}"

      return 2 ;;
  esac

  __cuesheet_to_splitpoints "${cuesheet_file}" > /dev/null 2> /dev/null
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: parsing cuesheet failed: ${errcode}"

    return 3
  fi

  return 0
}

## Bash functions

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

# Split a lossless range rip into tracks via the information from a given cuesheet.
function split_cue_lossless {
  local input_file
  local cuesheet_file

  local tmp_dir
  local errcode

  local input_extension
  local input_base
  local input_directory

  if [[ ! -f "${1}" ]]; then
    echo "error: file not found: ${1}"

    return 1
  fi

  input_file="${1}"

  if [[ ! -f "${2}" ]]; then
    echo "error: cuesheet file not found: ${2}"

    return 2
  fi

  cuesheet_file="${2}"

  tmp_dir=$(mktemp --directory 2> /dev/null)
  errcode=$?

  if [[ ${errcode} -ne 0 ]]; then
    echo "error: failed to create temporary directory: ${errcode}"

    return 3
  fi

  input_extension=$(get_fileext "${input_file}")
  input_base=$(basename --suffix=".${input_extension}" "${input_file}")
  input_directory=$(dirname "${input_file}")

  echo "info: input/output filename base is: ${input_base}"

  local -
  set -e

  __cuesheet_check "${cuesheet_file}"
  __decode_to_pcm_wav "${input_file}" "${tmp_dir}"
  __cuesheet_to_splitpoints "${cuesheet_file}" | shnsplit -q -d "${tmp_dir}" -- "${tmp_dir}"/input.wav

  rm "${tmp_dir}"/input.wav

  flac_encode "${tmp_dir}"

  find "${tmp_dir}" -regextype posix-egrep -regex ".*split\-track[0-9]+\.wav" -exec rm {} \;

  find "${tmp_dir}" -regextype posix-egrep -regex ".*split\-track[0-9]+\.flac" | \
  while read arg; do
    move_rename "${arg}" "${input_directory}" "split" "${input_base}"
  done

  rmdir "${tmp_dir}"
}
