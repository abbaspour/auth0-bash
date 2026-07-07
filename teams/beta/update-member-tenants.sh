#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-06-30
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a api_token] [-t team_slug] [-i member_id] [-T tenant_ids] [-r roles] [-C client_ids] [-v|-h]
        -e env        # Environment (default: prod). Use 'prod' for teams.auth0.com, or specify env like 'sus' for teams.sus.auth0.com
        -a token      # API access_token (opaque token, not JWT)
        -t slug       # Team slug
        -i id         # Team member ID (Auth0 user ID, e.g., auth0|xxx)
        -T ids        # Comma-separated tenant UUIDs to update (max 10; max 1 when -C is used)
        -r roles      # Comma-separated roles to assign (e.g., owner,editor-users)
        -C ids        # Comma-separated client IDs (only for editor-specific-apps role; limits -T to 1 tenant)
        -h|?          # usage
        -v            # verbose

eg,
     $0 -t my-team -i 'auth0|xxx' -T 538c9e21-e3d5-4ad6-b3d0-352c62369fb0 -r owner
     $0 -t my-team -i 'auth0|xxx' -T uuid1,uuid2 -r editor-users
     $0 -t my-team -i 'auth0|xxx' -T uuid1 -r editor-specific-apps -C client_123,client_456
END
    exit $1
}

declare api_token=''
declare TEAM_SLUG=''
declare member_id=''
declare tenant_ids=''
declare roles=''
declare client_ids=''
declare ENV='prod'

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:a:t:i:T:r:C:hv?" opt; do
    case ${opt} in
    e) ENV=${OPTARG} ;;
    a) api_token=${OPTARG} ;;
    t) TEAM_SLUG=${OPTARG} ;;
    i) member_id=${OPTARG} ;;
    T) tenant_ids=${OPTARG} ;;
    r) roles=${OPTARG} ;;
    C) client_ids=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${api_token}" ]] && { echo >&2 "ERROR: api_token undefined. Use -a or set api_token in .env"; usage 1; }
[[ -z "${TEAM_SLUG}" ]] && { echo >&2 "ERROR: TEAM_SLUG undefined. Use -t or set TEAM_SLUG in .env"; usage 1; }
[[ -z "${member_id}" ]] && { echo >&2 "ERROR: member_id undefined. Use -i"; usage 1; }
[[ -z "${tenant_ids}" ]] && { echo >&2 "ERROR: tenant_ids undefined. Use -T"; usage 1; }
[[ -z "${roles}" ]] && { echo >&2 "ERROR: roles undefined. Use -r"; usage 1; }

if [[ "${ENV}" == "prod" ]]; then
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.auth0.com"
else
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.${ENV}.auth0.com"
fi

declare tenants_json roles_json
tenants_json=$(echo "${tenant_ids}" | tr ',' '\n' | jq -R . | jq -s .)
roles_json=$(echo "${roles}" | tr ',' '\n' | jq -R . | jq -s .)

declare BODY
BODY=$(jq -n --argjson tenants "${tenants_json}" --argjson roles "${roles_json}" \
    '{tenants: $tenants, roles: $roles}')

if [[ -n "${client_ids}" ]]; then
    declare client_ids_json
    client_ids_json=$(echo "${client_ids}" | tr ',' '\n' | jq -R . | jq -s .)
    BODY=$(echo "${BODY}" | jq --argjson cids "${client_ids_json}" '. + {client_ids: $cids}')
fi

[[ -n "${opt_verbose}" ]] && echo "PATCH ${TEAMS_API_URL}/api/members/${member_id}/tenants" >&2
[[ -n "${opt_verbose}" ]] && echo "${BODY}" >&2

curl -s --request PATCH \
    -H "Authorization: Bearer ${api_token}" \
    -H "Content-Type: application/json" \
    --url "${TEAMS_API_URL}/api/members/${member_id}/tenants" \
    --data "${BODY}" | jq '.'
