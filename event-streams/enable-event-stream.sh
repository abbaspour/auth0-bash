#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2025-01-28
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -euo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-D|-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # event_stream_id
        -D          # Disable (default is to enable)
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
    exit $1
}

declare event_stream_id=''
declare status='enabled'

while getopts "e:a:i:Ehv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) event_stream_id=${OPTARG} ;;
    D) status='disabled' ;;
    v) set -x ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:event_streams"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${event_stream_id}" ]] && { echo >&2 "ERROR: event_stream_id undefined."; usage 1; }

readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

readonly BODY="{\"status\":\"${status}\"}"

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/event-streams/${event_stream_id}" \
    --data "${BODY}"
