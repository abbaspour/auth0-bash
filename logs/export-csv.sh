#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

declare -r tenant=amin01.au
declare -r domain=${tenant}.auth0.com
#declare -r param_query='q=(NOT type:fsa)'
declare -r param_query='q=(type:s)'
#declare -r param_query='q=(type:s)'

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:logs"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

#echo "log_id,date,user_id,browser"

curl -s --get -H "Authorization: Bearer ${access_token}" -H 'content-type: application/json' \
    --data-urlencode "${param_query}" \
    https://${domain}/api/v2/logs | jq -r '.[] | "\(.log_id),\(.date),\(.user_id),\(.user_agent)"'
