#!/usr/bin/env bash

##########################################################################################
# Author: Auth0
# Date: 2023-01-23
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare user_id=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i user_id  # user_id, e.g. 'auth0|5b5fb9702e0e740478884234'
        -t type     # type; "phone" or "email" or "totp" or "webauthn-roaming"
        -n name     # name
        -s secret   # totp secret
        -p number   # phone number
        -m email    # email
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'auth0|5b5fb9702e0e740478884234' -t phone -p +614000000 -n sms
END
    exit $1
}

declare type=''
declare phone_number=''

while getopts "e:a:i:t:p:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) user_id=${OPTARG} ;;
    t) type=${OPTARG} ;;
    p) phone_number=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:authentication_methods"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${user_id}" ]] && { echo >&2 "ERROR: user_id undefined."; usage 1; }
[[ -z "${type}" ]] && { echo >&2 "ERROR: type undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

# todo: add other methods support

declare BODY=$(cat <<EOL
{
    "type": "${type}",
    "phone_number": "${phone_number}"
}
EOL
)

curl -s -H "Authorization: Bearer ${access_token}" \
    --header 'content-type: application/json' -d "${BODY}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/users/${user_id}/authentication-methods" | jq .