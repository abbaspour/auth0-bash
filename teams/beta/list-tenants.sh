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
USAGE: $0 [-e env] [-a api_token] [-t team_slug] [-k take] [-n next] [-s sort] [-E environment] [-T environment_tag] [-l locality] [-v|-h]
        -e env        # Environment (default: prod). Use 'prod' for teams.auth0.com, or specify env like 'sus' for teams.sus.auth0.com
        -a token      # API access_token (opaque token, not JWT)
        -t slug       # Team slug
        -k take       # Max tenants to return (1-50, default 50)
        -n next       # Pagination cursor (value of 'next' from previous response)
        -s sort       # Sort order: created_at:1 (oldest first) | created_at:-1 (newest first, default)
        -E env        # Filter by environment name (e.g., US-3, EU-1, acme-dev)
        -T tag        # Filter by environment tag: development | staging | production
        -l locality   # Filter by locality (e.g., us, eu, virginia, frankfurt)
        -h|?          # usage
        -v            # verbose

eg,
     $0 -t my-team
     $0 -t my-team -k 10 -s created_at:1
     $0 -t my-team -E US-3 -T production
     $0 -t my-team -l eu -k 20
END
    exit $1
}

declare api_token=''
declare TEAM_SLUG=''
declare take=''
declare next=''
declare sort=''
declare environment=''
declare environment_tag=''
declare locality=''
declare ENV='prod'

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:a:t:k:n:s:E:T:l:hv?" opt; do
    case ${opt} in
    e) ENV=${OPTARG} ;;
    a) api_token=${OPTARG} ;;
    t) TEAM_SLUG=${OPTARG} ;;
    k) take=${OPTARG} ;;
    n) next=${OPTARG} ;;
    s) sort=${OPTARG} ;;
    E) environment=${OPTARG} ;;
    T) environment_tag=${OPTARG} ;;
    l) locality=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${api_token}" ]] && { echo >&2 "ERROR: api_token undefined. Use -a or set api_token in .env"; usage 1; }
[[ -z "${TEAM_SLUG}" ]] && { echo >&2 "ERROR: TEAM_SLUG undefined. Use -t or set TEAM_SLUG in .env"; usage 1; }

if [[ "${ENV}" == "prod" ]]; then
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.auth0.com"
else
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.${ENV}.auth0.com"
fi

declare params=''
[[ -n "${take}" ]] && params="${params}&take=${take}"
[[ -n "${next}" ]] && params="${params}&from=${next}"
[[ -n "${sort}" ]] && params="${params}&sort=${sort}"
[[ -n "${environment}" ]] && params="${params}&environment=${environment}"
[[ -n "${environment_tag}" ]] && params="${params}&environment_tag=${environment_tag}"
[[ -n "${locality}" ]] && params="${params}&locality=${locality}"
params="${params#&}"

declare url="${TEAMS_API_URL}/api/tenants"
[[ -n "${params}" ]] && url="${url}?${params}"

[[ -n "${opt_verbose}" ]] && echo "GET ${url}" >&2

curl -s -H "Authorization: Bearer ${api_token}" \
    --url "${url}" | jq '.'
