#!/usr/bin/env bash

binary=""
UHAUL_CLEAN_OUTPUT="${UHAUL_CLEAN_OUTPUT:-1}"
UHAUL_BIN_PREFIX="${UHAUL_BIN_PREFIX:-uhaul}"
UHAUL_OUTPUT_DIRECTORY="${UHAUL_OUTPUT_DIRECTORY:-out}"
UHAUL_SET_INTERPRETER="${UHAUL_SET_INTERPRETER:-1}"

show_help() {
  printf "Usage: %s [options] binary\n" "$(basename "$0")"
  printf "Options:\n"
  printf "  -i, --interpreter  Set interpreter (default: 1)\n"
  printf "  -h, --help         Show this help message\n"
  printf "  -c, --clean        Clean output directory (default: 1)\n"
  printf "  -p, --prefix       Set binary prefix (default: uhaul)\n"
  printf "  -o, --out          Set output directory (default: out)\n"
}

die() {
  message="$1"
  shift
  printf >&2 "%s\n" "$message" "$@"
  exit 1
}

while :; do
  case $1 in
    -i|--interpreter)
      UHAUL_SET_INTERPRETER=1
      shift
      ;;
    -h|--help)
      show_help
      exit
      ;;
    -c|--clean)
      UHAUL_CLEAN_OUTPUT=1
      shift
      ;;
    -p|--prefix)
      UHAUL_BIN_PREFIX="$2"
      shift
      shift
      ;;
    -o|--out)
      UHAUL_OUTPUT_DIRECTORY="$2"
      shift
      shift
      ;;
    -*)
      die "Invalid flag specified %s\n\n" "$1"
      ;;
    *)
      if [ -z "$1" ] ; then
        die "Binary should be specified"
      fi
      binary="$1"
      shift
      break
      ;;
  esac
done

set -euo pipefail

get_dynamic_section() {
  dynamic_binary=$1
  section=$2
  shift
  shift
  readelf -d "$dynamic_binary" | grep "$section" | sed "s/^.*\:\ //g" | tr -d "[]"
}

get_ldd_deps() {
  dynamic_binary=$1
  shift
  ldd "$dynamic_binary" | tail -n +2 | sed 's/^.*=//g ; s/[(][^)]*[)]//g ; s/> //g'
}

usable_binary="$(realpath "$binary")"
interpreter="$(ldd "$usable_binary" | head -n 1 | awk '{$1=$1};1' | sed 's/[(][^)]*[)]//g')"
dependencies="$(get_ldd_deps "$usable_binary")"

if [ "$UHAUL_CLEAN_OUTPUT" -eq 1 ] ; then
  rm -rf "$UHAUL_OUTPUT_DIRECTORY"
fi

target_usr_dir="$UHAUL_OUTPUT_DIRECTORY/$UHAUL_BIN_PREFIX/usr"
mkdir -p "$target_usr_dir/bin" "$target_usr_dir/lib"
target_out_binary="$target_usr_dir/bin/$(basename "$usable_binary")"
cp -f "$usable_binary" "$target_out_binary"
chmod 755 "$target_out_binary"
printf "Setting RPATH to prefix"

if [ "$UHAUL_SET_INTERPRETER" -eq 1 ] ; then
  patchelf \
    --set-rpath "$target_usr_dir/lib" \
    --set-interpreter "$interpreter" \
    "$target_out_binary"
else
  patchelf \
    --set-rpath "$target_usr_dir/lib" \
    "$target_out_binary"
fi
chmod 555 "$target_out_binary"

for dep in $dependencies ; do
  depname="$(basename "$dep")"
  cp -f "$dep" "$target_usr_dir/lib"
  chmod 755 "$target_usr_dir/lib/$depname"
  patchelf --set-rpath "$target_usr_dir/lib" "$target_usr_dir/lib/$depname"
  chmod 555 "$target_usr_dir/lib/$depname"
done
