#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-07-07
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i member_id] [-T tenant_ids] [-v|-h]
        -e file       # .env file location (default cwd)
        -a token      # access_token. default from environment variable
        -i id         # Team member ID (Auth0 user ID, e.g., auth0|xxx)
        -T ids        # Comma-separated tenant UUIDs to remove access from (max 10)
        -h|?          # usage
        -v            # verbose

eg,
     $0 -i 'auth0|xxx' -T 538c9e21-e3d5-4ad6-b3d0-352c62369fb0
     $0 -i 'auth0|xxx' -T uuid1,uuid2
END
    exit $1
}

declare member_id=''
declare tenant_ids=''
declare -i opt_verbose=0

while getopts "e:a:i:T:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) member_id=${OPTARG} ;;
    T) tenant_ids=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${member_id}" ]] && { echo >&2 "ERROR: member_id undefined. Use -i"; usage 1; }
[[ -z "${tenant_ids}" ]] && { echo >&2 "ERROR: tenant_ids undefined. Use -T"; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:members"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r TEAMS_API_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .aud | if type == "array" then .[0] else . end | rtrimstr("/api/")' <<< "${access_token}")

declare tenants_json
tenants_json=$(echo "${tenant_ids}" | tr ',' '\n' | jq -R . | jq -s .)

declare BODY
BODY=$(jq -n --argjson tenants "${tenants_json}" '{tenants: $tenants}')

[[ ${opt_verbose} -eq 1 ]] && echo "DELETE ${TEAMS_API_URL}/api/members/${member_id}/tenants" >&2
[[ ${opt_verbose} -eq 1 ]] && echo "${BODY}" >&2

curl -s --request DELETE \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json" \
    --url "${TEAMS_API_URL}/api/members/${member_id}/tenants" \
    --data "${BODY}" | jq '.'
