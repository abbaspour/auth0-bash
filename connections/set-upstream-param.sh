#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-05-28
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i client_id] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i conn_id      # connection id
        -n name         # upstream params name
        -d dynamic      # dynamic value alias name
        -s static       # static value
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i con_xyz
END
    exit $1
}

declare connection_id=''
declare type=''
declare value=''
declare name=''

while getopts "e:a:i:n:d:s:dhv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    i) connection_id=${OPTARG} ;;
    n) name=${OPTARG};;
    d) type='alias'; value=${OPTARG};;
    s) type='value'; value=${OPTARG};;
    v) set -x ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:connections"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${connection_id}" ]] && { echo >&2 "ERROR: connection_id undefined."; usage 1; }
[[ -z "${name}" ]] && { echo >&2 "ERROR: name undefined."; usage 1; }
[[ -z "${value}" ]] && { echo >&2 "ERROR: value undefined."; usage 1; }

readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

readonly BODY=$(curl --silent --request GET \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" \
    --header 'content-type: application/json' | \
    jq "del(.realms, .id, .strategy, .name, .provisioning_ticket_url) | .options += {\"upstream_params\": { \"${name}\": {\"${type}\": \"${value}\"} } }" )

curl -s --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" | jq .
