#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-07-13
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -euo pipefail

command -v zbarimg >/dev/null || { echo >&2 "error: zbarimg not found. brew install zbar";  exit 3; }

readonly image_file=$(mktemp --suffix .bmp)

#echo "image file: ${image_file}"
readonly data=$(screencapture -i "${image_file}" && zbarimg -q --raw "${image_file}")

echo "${data}" | egrep -E "enrollment_tx_id=(\w+)" -o
echo "${data}" | egrep -E "secret=([^&]+)" -o
