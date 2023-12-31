#!/bin/bash
# This script will backup an optical disc using MakeMKV running on MacOS
# Informational logs are output to stderr
# CSV data of the resulting file is output to stdout
# Usage: ./autoripper.sh >> output.csv

output_dir="${output_dir:-"$HOME/Movies/backup"}"
preset_name="${preset_name:-"DS9DVDRIP"}"
preset_file="${preset_file:-""}"

disc_index="0"
min_length="120"
cache_size="1024"
use_directio="true"
eject_when_done="true"

# Messages can be output to a file or one of these special values: -stdout, -stderr, -null
message_output="-stderr"
progress_output="-null" # Progress can use same output as messages if set to: -same

# same as echo but output to stderr (used for info/error messages)
function echoerr(){
  echo "$@" 1>&2;
}

################################################################################
# Functions below are used rather than calling the underlying commmands directly
# This is done to make handling Linux/MacOS differences easier
################################################################################

# Handle calling makemkvcon binary even when not in PATH
function _makemkvcon(){
  /Applications/MakeMKV.app/Contents/MacOS/makemkvcon $@
}

# Returns the sha256 hash of a file
function calc_file_hash(){
  shasum -a256 $1 | cut -d' ' -f1
}

# Returns the size of a file in bytes
function get_file_size(){
  stat -f%z $1
}

function eject_disc_tray(){
  if [[ $eject_when_done == "true" || $eject_when_done == "1" || $eject_when_done == "yes" ]]; then
    drutil tray eject
  else
    echoerr "Skipping disc ejection"
  fi
}

function backupdisc(){
  disc_title=$(_makemkvcon -r info | grep "DRV:${disc_index}" | sed -E 's/.+,"(.+)","\/dev\/.+"$/\1/')
  output_path="${output_dir}/${disc_title}.iso"
  echoerr "Backing up ${disc_title} to ${output_path}"
  start_time=$(date +%s)
  _makemkvcon -r \
    --minlength=${min_length} --decrypt \
    --noscan \
    --cache=${cache_size} --directio=${use_directio} \
    --messages=${message_output} --progress=${progress_output} \
    backup disc:${disc_index} ${output_path}
  end_time=$(date +%s)

  # Collect info about the job+file
  elapsed_seconds=$(($end_time-$start_time))
  file_hash=$(calc_file_hash $output_path)
  file_bytes=$(get_file_size $output_path)

  # Output CSV info
  echo "${disc_title},${file_bytes},${elapsed_seconds},${file_hash},${output_path},${min_length},${cache_size},${use_directio}"
}

# Given a disc source input and Handbrake profile, encode a video file
function encode_disc(){
  input_disc=$1
  # Scan input file and extract the JSON info through terrible regex parsing
  # Get JSON output; then extract everything from the line with "JSON Title Set:"; then remove all newlines; then remove first 16 characters, pipe to jq
  title_json=$(handbrakecli --json -i ${input_disc} --scan --title 0 | sed -ne '/JSON Title Set/,$ p' | tr -d '\n' | cut -c16- | jq -cr)
  preset_args=""

  if [ ! -z $preset_file ]; then
    preset_args="--preset-import-file ${preset_file} --preset=${preset_name}"
  fi

  # Loop through the indexes of titles we are interested in
  for tIndex in $(echo $title_json | jq -cr '.TitleList[].Index'); do
    handbrakecli -t ${tIndex} -i ${input_disc} -o $HOME/Movies/$(basename ${input_disc} .iso)-t${tIndex}.mp4 ${preset_args}
  done
}

# Begin main script execution
if [ "$1" == "encode" ]; then
  encode_disc $2
elif [ "$1" == "rip" ]; then
  backupdisc
  eject_disc_tray
elif [ "$1" == "" ]; then
  echo "Error - No command provided"
  exit 1
else
  echo "Unknown command: ${1}"
  exit 1
fi
