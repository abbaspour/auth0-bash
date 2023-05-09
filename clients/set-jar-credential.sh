#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-01-25
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i client_id] [-u url1,url2] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # client_id
        -c cred_id      # credential id
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i 62qDW3H3goXmyJTvpzQzMFGLpVGAJ1Qh -c cred_gzZaR1bzt3B4CC9Q33sFee
END
    exit $1
}

declare client_id=''
declare credential_id=''

while getopts "e:a:i:c:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) client_id=${OPTARG} ;;
    c) credential_id=${OPTARG} ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPES=("update:clients" "update:client_keys") # Either of these scopes would do
[[ " $AVAILABLE_SCOPES " == *" ${EXPECTED_SCOPES[0]} "* || " $AVAILABLE_SCOPES " == *" ${EXPECTED_SCOPES[1]} "*  ]] \
    || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected (any of): '${EXPECTED_SCOPES[*]}', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${client_id}" ]] && {  echo >&2 "ERROR: client_id undefined." ;  usage 1; }
[[ -z "${credential_id}" ]] && {  echo >&2 "ERROR: credential_id undefined." ;  usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare -r signed_request_object=$(cat <<EOL
{
  "signed_request_object": {
      "credentials": [{"id": "${credential_id}"}]
  }
}
EOL
)

curl -s --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${signed_request_object}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/clients/${client_id}"

