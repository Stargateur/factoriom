#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
  cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-t path] -s path

-t, --target-directory Directory path where the archive will be create
-s, --source-directory Directory path of the mod
-h, --help      Print this help and exit
-v, --verbose   Print script debug info
EOF
  exit
}

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

setup_colors() {
  if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
    NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
  else
    NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
  fi
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

check_requirements() {
  command -v 7z || die "Missing 7z, see https://www.7-zip.org/download.html"
  command -v jq || die "Missing jq, see https://stedolan.github.io/jq/"
}

parse_ostype() {
  if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "~/.factorio/mods"
  elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "~/Library/Application Support/factorio/mods"
  elif [[ "$OSTYPE" == "cygwin" ]]; then
    echo "$APPDATA/factorio/mods"
  elif [[ "$OSTYPE" == "msys" ]]; then
    echo "$APPDATA/factorio/mods"
  elif [[ "$OSTYPE" == "win32" ]]; then
    echo "$APPDATA/factorio/mods"
  elif [[ "$OSTYPE" == "freebsd"* ]]; then
    echo "~/.factorio/mods"
  else
    echo "~/.factorio/mods"
  fi
}

parse_params() {
  target=$(parse_ostype)

  while :; do
    case "${1-}" in
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -s | --source-directory)
      source="${2-}"
      shift
      ;;
    -t | --target-directory)
      target="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  [[ -z "${source-}" ]] && die "Missing required parameter: source-directory"
  [[ ${#args[@]} -ne 0 ]] && die "Script take no arguments"

  return 0
}

parse_params "$@"
setup_colors
check_requirements

version=$(jq .version "${source}/info.json" -r)
name=$(jq .name "${source}/info.json" -r)
msg "Found ${name} ${version}"

# We use ls to not include hidden files
7z u "${target}/${name}_${version}.zip" $(ls ${source}/* -d)
