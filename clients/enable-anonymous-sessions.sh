#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-10-13
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
#
# Enable (or disable) anonymous sessions on a client.
# Requires scope: update:clients
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i client_id] [-d] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # client_id
        -d              # disable anonymous sessions (default: enable)
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i 62qDW3H3goXmyJTvpzQzMFGLpVGAJ1Qh
     $0 -i 62qDW3H3goXmyJTvpzQzMFGLpVGAJ1Qh -d
END
    exit $1
}

declare client_id=''
declare active=true
declare opt_verbose=0

while getopts "e:a:i:dhv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) client_id=${OPTARG} ;;
    d) active=false ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined."; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:clients"
[[ " ${AVAILABLE_SCOPES} " == *" ${EXPECTED_SCOPE} "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '${EXPECTED_SCOPE}', Available: '${AVAILABLE_SCOPES}'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<< "${access_token}")

declare -r BODY=$(cat <<EOL
{
  "anonymous_sessions": {
    "active": ${active}
  }
}
EOL
)

[[ ${opt_verbose} -eq 1 ]] && echo >&2 "${BODY}"

curl -s --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --header 'content-type: application/json' \
    --data "${BODY}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/clients/${client_id}" | jq .
