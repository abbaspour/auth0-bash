#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-05-08
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-c id] [-v|-h]
        -e file          # .env file location (default cwd)
        -a token         # access_token. default from environment variable
        -c client_id     # client id
        -i credential_id # credential id
        -h|?             # usage
        -v               # verbose

eg,
     $0 -i c123 -c cred123
END
    exit $1
}

declare client_id=''
declare credential_id=''

while getopts "e:a:c:i:n:s:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    c) client_id=${OPTARG} ;;
    i) credential_id=${OPTARG} ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="delete:client_credentials"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined.";  usage 1; }
[[ -z "${credential_id}" ]] && { echo >&2 "ERROR: credential_id undefined.";  usage 1; }


declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

curl -k --request DELETE \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/clients/${client_id}/credentials/${credential_id}"
