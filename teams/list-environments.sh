#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-07-07
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-v|-h]
        -e file       # .env file location (default cwd)
        -a token      # access_token. default from environment variable
        -h|?          # usage
        -v            # verbose

eg,
     $0
END
    exit $1
}

declare -i opt_verbose=0

while getopts "e:a:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:members"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r TEAMS_API_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .aud | if type == "array" then .[0] else . end | rtrimstr("/api/")' <<< "${access_token}")

[[ ${opt_verbose} -eq 1 ]] && echo "GET ${TEAMS_API_URL}/api/environments" >&2

curl -s -H "Authorization: Bearer ${access_token}" \
    --url "${TEAMS_API_URL}/api/environments" | jq '.'
