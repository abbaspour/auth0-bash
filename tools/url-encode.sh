#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

which curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
which jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
urlencode() {
    local length="${#1}"
    for ((i = 0; i < length; i++)); do
        local c="${1:i:1}"
        case $c in
        [a-zA-Z0-9.~_-]) printf "$c" ;;
        *) printf '%s' "$c" | xxd -p -c1 |
            while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}

urlencode $*
echo
