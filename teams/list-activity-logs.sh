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
USAGE: $0 [-e env] [-a api_token] [-t team_slug] [-k take] [-n next] [-S since] [-U until] [-T type] [-s status] [-v|-h]
        -e env        # Environment (default: prod). Use 'prod' for teams.auth0.com, or specify env like 'sus' for teams.sus.auth0.com
        -a token      # API access_token (opaque token, not JWT)
        -t slug       # Team slug
        -k take       # Max log entries to return (1-50, default 50)
        -n next       # Pagination cursor (value of 'next' from previous response)
        -S since      # Return logs at or after this ISO 8601 timestamp (e.g., 2026-01-01T00:00:00Z)
        -U until      # Return logs before this ISO 8601 timestamp
        -T type       # Filter by event type: "Team Member" | "Team Invitation" | "Security Policy" |
                      #   "Team Settings" | "Token Activity" | "Tenant Activity" | "Tenant Member" | "Team Activity"
        -s status     # Filter by status: Success | Failure
        -h|?          # usage
        -v            # verbose

eg,
     $0 -t my-team
     $0 -t my-team -k 20 -S 2026-01-01T00:00:00Z
     $0 -t my-team -T "Tenant Activity" -s Success
     $0 -t my-team -n <cursor>
END
    exit $1
}

declare api_token=''
declare TEAM_SLUG=''
declare take=''
declare next=''
declare since=''
declare until=''
declare type=''
declare status=''
declare ENV='prod'

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:a:t:k:n:S:U:T:s:hv?" opt; do
    case ${opt} in
    e) ENV=${OPTARG} ;;
    a) api_token=${OPTARG} ;;
    t) TEAM_SLUG=${OPTARG} ;;
    k) take=${OPTARG} ;;
    n) next=${OPTARG} ;;
    S) since=${OPTARG} ;;
    U) until=${OPTARG} ;;
    T) type=${OPTARG} ;;
    s) status=${OPTARG} ;;
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
[[ -n "${since}" ]] && params="${params}&since=${since}"
[[ -n "${until}" ]] && params="${params}&until=${until}"
[[ -n "${type}" ]] && params="${params}&type=${type// /%20}"
[[ -n "${status}" ]] && params="${params}&status=${status}"
params="${params#&}"

declare url="${TEAMS_API_URL}/api/activity/logs"
[[ -n "${params}" ]] && url="${url}?${params}"

[[ -n "${opt_verbose}" ]] && echo "GET ${url}" >&2

curl -s -H "Authorization: Bearer ${api_token}" \
    --url "${url}" | jq '.'
