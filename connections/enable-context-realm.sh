#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

### usage in custom-db
# function login(email, password, context, callback) {
#    // context.realm
# }
set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i connection_id] [-c cert-file] [-p key-file] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # connection_id
        -D          # Disable (default is to enable)
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
    exit $1
}

declare connection_id=''
declare mode=true

while getopts "e:a:i:Ehv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) connection_id=${OPTARG} ;;
    D) mode=false ;;
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

readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

readonly BODY=$(curl --silent --request GET \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" \
    --header 'content-type: application/json' | jq "del(.realms, .id, .strategy, .name, .provisioning_ticket_url) | .options += {\"realm_fallback\": ${mode}, \"enable_script_context\": ${mode} }")

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" \
    --data "${BODY}"
