#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-01-23
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v openssl >/dev/null || { echo >&2 "error: openssh not found";  exit 3; }

readonly b=$(basename "${1}")
openssl ec -in "${1}" -pubout -out "public-${b}"