#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################


set -euo pipefail

which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }
which jq > /dev/null || { echo >&2 "error: jq not found"; exit 3; }

declare -r DIR=$(dirname ${BASH_SOURCE[0]})



<<<<<<< HEAD
which awk >/dev/null || {
    echo >&2 "error: awk not found"
    exit 3
}
=======

>>>>>>> 4f4050b (fix: add extra check for curl and jq availabilty)

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i identifier] [-n name] [-s scope] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i identifer    # API identifier (e.g. my.api)
        -n name         # API name (e.g. "My API")
        -s scopes       # comma separated scopes
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i my.api -n "My API" -s read:data,write:data
END
    exit $1
}

declare api_identifier=''
declare api_name=''
declare api_scopes=''

while getopts "e:a:i:n:s:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) api_identifier=${OPTARG} ;;
    n) api_name=${OPTARG} ;;
    s) api_scopes=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {
    echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
    usage 1
}
[[ -z "${api_identifier}" ]] && {
    echo >&2 "ERROR: api_identifier undefined."
    usage 1
}
[[ -z "${api_name}" ]] && {
    echo >&2 "ERROR: api_name undefined."
    usage 1
}

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

for s in $(echo $api_scopes | tr ',' ' '); do
    scopes+="{\"value\":\"${s}\"},"
done
scopes=${scopes%?}

declare BODY=$(
    cat <<EOL
{
  "identifier": "${api_identifier}",
  "name": "${api_name}",
  "scopes": [ ${scopes} ]
}
EOL
)

curl -k --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/resource-servers
