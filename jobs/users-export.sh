#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-11-16
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare format='csv'
declare fields_str=''
declare connection_id=''
declare -i limit=1000000

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-c connection_id] [-f field1,field2] [-l limit] [-j|-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -c id       # connection_id
        -f fields   # comma seperated fields (TBA)
        -l limit    # number of records. default is 1000000
        -j          # JSON export. default is CSV
        -h|?        # usage
        -v          # verbose

eg,
     $0 -j -c con_Z1QogOOq4sGa1iR9
END
    exit $1
}

while getopts "e:a:f:c:l:jhv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    c) connection_id=${OPTARG} ;;
    f) fields_str=${OPTARG} ;;
    l) limit=${OPTARG} ;;
    j) format='json';;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:users"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${connection_id}" ]] && { echo >&2 "ERROR: connection_id undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare BODY=$(cat <<EOL
{
  "connection_id": "${connection_id}",
  "format": "${format}",
  "limit": ${limit}
}
EOL
)

curl -s --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --header 'content-type: application/json' \
    --data "${BODY}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/jobs/users-exports" | jq -r '.id'

