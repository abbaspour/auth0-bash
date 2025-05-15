#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2025-02-20
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-t trigger_id] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -t trigger_id   # trigger id. eg: post-login, pre-user-registration
        -h|?            # usage
        -v              # verbose

eg,
     $0
     $0
END
    exit $1
}

declare trigger_id=''

while getopts "e:a:t:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    t) trigger_id=${OPTARG} ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${trigger_id}" ]] && { echo >&2 "ERROR: trigger_id undefined."; usage 1; }
[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:actions"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

declare BODY='{"bindings":[]}'

curl -s -X PATCH -H "Authorization: Bearer ${access_token}" \
    -H 'Content-Type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/actions/triggers/${trigger_id}/bindings" \
    -d "${BODY}"
