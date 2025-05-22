#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2025-05-22
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i client_id] [-m k1:v1,k2:v2] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # client_id
        -h number       # per hour client-credentials token quota
        -d number       # per day client-credentials token quota
        -t              # enforce limits true
        -f              # enforce limits false
        -?              # usage
        -v              # verbose

eg,
     $0 -i 62qDW3H3goXmyJTvpzQzMFGLpVGAJ1Qh -d 100 -h 10 -f
END
    exit $1
}

declare client_id=''
declare per_hour=''
declare per_day=''
declare enforce=''

while getopts "e:a:i:h:d:tfv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) client_id=${OPTARG} ;;
    h) per_hour=${OPTARG} ;;
    d) per_day=${OPTARG} ;;
    t) enforce='true' ;;
    f) enforce='false' ;;
    v) opt_verbose=1 ;; #set -x;;
    ?) usage 0 ;;
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

declare payload=''

[[ -n "${per_hour}" ]] && payload+="\"per_hour\": ${per_hour}"

if [[ -n "${per_day}" ]]; then
  [[ -n "${payload}" ]] && payload+=","
  payload+="\"per_day\": ${per_day}"
fi

if [[ -n "${enforce}" ]]; then
  [[ -n "${payload}" ]] && payload+=","
  payload+="\"enforce\": ${enforce}"
fi

declare BODY=$(cat <<EOL
{
  "token_quota": {
    "client_credentials": {
      ${payload}
    }
  }
}
EOL
)

curl -s --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/clients/${client_id}"

echo
