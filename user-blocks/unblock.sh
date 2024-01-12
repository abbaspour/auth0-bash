#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-u user_id] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # Access Token
        -i identifer   # block identifer (email, phone, username, etc)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -i username
END
    exit $1
}

declare identifier=''
declare opt_verbose=0

while getopts "e:a:i:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) identifier=${OPTARG} ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE'";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:users"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${identifier}" ]] && { echo >&2 "ERROR: identifier undefined.";  usage 1; }


declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

curl -s --request DELETE -G \
    -H "Authorization: Bearer ${access_token}" \
    --data-urlencode "identifier=${identifier}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/user-blocks"
