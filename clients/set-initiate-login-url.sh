#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-01-25
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i client_id] [-u url1] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # client_id
        -u url          # initiate_login_url
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i 62qDW3H3goXmyJTvpzQzMFGLpVGAJ1Qh -u https://app1.example.com/bclo
END
    exit $1
}

declare client_id=''
declare initiate_login_url=''

while getopts "e:a:i:u:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) client_id=${OPTARG} ;;
    u) initiate_login_url=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPES=("update:clients" "update:client_keys") # Either of these scopes would do
[[ " $AVAILABLE_SCOPES " == *" ${EXPECTED_SCOPES[0]} "* || " $AVAILABLE_SCOPES " == *" ${EXPECTED_SCOPES[1]} "*  ]] \
    || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected (any of): '${EXPECTED_SCOPES[*]}', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

[[ -z "${client_id}" ]] && {  echo >&2 "ERROR: client_id undefined." ;  usage 1; }
[[ -z "${initiate_login_url}" ]] && { echo >&2 "ERROR: initiate_login_url undefined.";  usage 1; }

declare BODY=$(cat <<EOL
{
  "initiate_login_uri": "${initiate_login_url}"
}
EOL
)

if [[ ${opt_verbose} -eq 1 ]]; then
    echo "${BODY}"
fi

curl -s --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/clients/${client_id}"

echo