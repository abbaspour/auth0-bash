#!/usr/bin/env bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

[[ $# -lt 1 ]] && jwt=$access_token || jwt=$1
jq -Rr 'split(".") | .[1] | @base64d | fromjson' <<<"${access_token}"
