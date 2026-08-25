#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-08-25
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
#
# Enables the agent subject claim (agent_subject_claims: auth0-v1) for a resource server.
# The following arguments are required:
#   -i: The id of the resource server.
##########################################################################################

set -euo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # resource_server id
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i rs_123456789
END
    exit $1
}

declare resource_server_id=''
declare opt_verbose=''

while getopts "e:a:i:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) resource_server_id=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:resource_servers"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${resource_server_id}" ]] && { echo >&2 "ERROR: resource_server_id undefined.";  usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<<"${access_token}")

declare BODY=$(cat <<EOL
{
  "agent_subject_claims": "auth0-v1"
}
EOL
)

[[ -n "${opt_verbose}" ]] && echo "${BODY}"

# Update the resource server.
curl -s --request PATCH \
  --url "${AUTH0_DOMAIN_URL}api/v2/resource-servers/${resource_server_id}" \
  --header "authorization: Bearer ${access_token}" \
  --header 'content-type: application/json' \
  --data "${BODY}" | jq .
