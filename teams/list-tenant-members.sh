#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-01-08
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a api_token] [-t team_slug] [-i tenant_id] [-v|-h]
        -e env        # Environment (default: prod). Use 'prod' for teams.auth0.com, or specify env like 'sus' for teams.sus.auth0.com
        -a token      # API access_token (opaque token, not JWT)
        -t slug       # Team slug
        -i id         # Tenant ID (UUID format, e.g., 538c9e21-e3d5-4ad6-b3d0-352c62369fb0)
        -h|?          # usage
        -v            # verbose

eg,
     $0 -t my-team -i 538c9e21-e3d5-4ad6-b3d0-352c62369fb0
     $0 -e sus -i 538c9e21-e3d5-4ad6-b3d0-352c62369fb0
END
    exit $1
}

declare api_token=''
declare TEAM_SLUG=''
declare tenant_id=''
declare ENV='prod'

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:a:t:i:hv?" opt; do
    case ${opt} in
    e) ENV=${OPTARG} ;;
    a) api_token=${OPTARG} ;;
    t) TEAM_SLUG=${OPTARG} ;;
    i) tenant_id=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

# Basic validation (no JWT decoding for opaque tokens)
[[ -z "${api_token}" ]] && { echo >&2 "ERROR: api_token undefined. Use -a or set api_token in .env"; usage 1; }
[[ -z "${TEAM_SLUG}" ]] && { echo >&2 "ERROR: TEAM_SLUG undefined. Use -t or set TEAM_SLUG in .env"; usage 1; }
[[ -z "${tenant_id}" ]] && { echo >&2 "ERROR: tenant_id undefined. Use -i"; usage 1; }

# Construct Teams API base URL
if [[ "${ENV}" == "prod" ]]; then
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.auth0.com"
else
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.${ENV}.auth0.com"
fi

curl -s -H "Authorization: Bearer ${api_token}" \
    --url "${TEAMS_API_URL}/api/tenants/${tenant_id}/members" | jq '.'
