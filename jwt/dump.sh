#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

[[ $# -lt 1 ]] && jwt=$access_token || jwt=$1
jq -Rr 'split(".") | .[1] | @base64d | fromjson' <<<"${jwt}"
