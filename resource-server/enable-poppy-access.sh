#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-11-18
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
#
# Enable (or disable) personal agent protocol (poppy) access on a resource server.
# Requires scope: update:resource_servers
##########################################################################################

set -euo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-d] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # resource_server id
        -d              # disable (sets use_for_personal_agent_protocol to false)
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i 6501a2b3c4d5e6f7a8b9c0d1
     $0 -i 6501a2b3c4d5e6f7a8b9c0d1 -d
END
    exit $1
}

declare resource_server_id=''
declare enabled=true
declare opt_verbose=''

while getopts "e:a:i:dhv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) resource_server_id=${OPTARG} ;;
    d) enabled=false ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token:-}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${resource_server_id}" ]] && { echo >&2 "ERROR: resource_server_id undefined."; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:resource_servers"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<<"${access_token}")

declare -r BODY="{ \"use_for_personal_agent_protocol\": ${enabled} }"

[[ -n "${opt_verbose}" ]] && echo >&2 "${BODY}"

curl -s --request PATCH \
  --url "${AUTH0_DOMAIN_URL}api/v2/resource-servers/${resource_server_id}" \
  --header "authorization: Bearer ${access_token}" \
  --header 'content-type: application/json' \
  --data "${BODY}" | jq .
