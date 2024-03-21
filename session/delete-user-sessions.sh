#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-03-20 Happy Nowruz
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -euo pipefail

command -v jq >/dev/null || { echo >&2 "error: jq not found";  exit 3; }
command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i user_id  # user_id
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'auth0|b0dec5bdba02248abd51388'
END
    exit $1
}

urlencode() {
    jq -rn --arg x "${1}" '$x|@uri'
}

declare user_id=''

while getopts "e:a:i:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) user_id=$(urlencode "${OPTARG}") ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z ${access_token} ]] && { echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"
    exit 1
}

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="delete:sessions"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z ${user_id} ]] && { echo >&2 "ERROR: no 'user_id' defined"; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

curl -s -X DELETE -H "Authorization: Bearer ${access_token}" -H 'content-type: application/json' \
    "${AUTH0_DOMAIN_URL}api/v2/users/${user_id}/sessions" | jq .
