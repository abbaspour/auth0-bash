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
USAGE: $0 [-e env] [-a api_token] [-t team_slug] [-i member_id] [-v|-h]
        -e env        # Environment (default: prod). Use 'prod' for teams.auth0.com, or specify env like 'sus' for teams.sus.auth0.com
        -a token      # API key (opaque token, not JWT)
        -t slug       # Team slug
        -i id         # Team member ID (Auth0 user ID, e.g., auth0|xxx or google-oauth2|xxx)
        -h|?          # usage
        -v            # verbose

eg,
     $0 -t my-team -i 'auth0|68da0038bab277c02ed1d4c8'
     $0 -e sus -t my-team -i 'google-oauth2|123456789012345678901'
END
    exit $1
}

declare api_token=''
declare TEAM_SLUG=''
declare member_id=''
declare ENV='prod'
declare -i opt_verbose=0

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:a:t:i:hv?" opt; do
    case ${opt} in
    e) ENV=${OPTARG} ;;
    a) api_token=${OPTARG} ;;
    t) TEAM_SLUG=${OPTARG} ;;
    i) member_id=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

# Basic validation (no JWT decoding for opaque tokens)
[[ -z "${api_token}" ]] && { echo >&2 "ERROR: api_token undefined. Use -a or set api_token in .env"; usage 1; }
[[ -z "${TEAM_SLUG}" ]] && { echo >&2 "ERROR: TEAM_SLUG undefined. Use -t or set TEAM_SLUG in .env"; usage 1; }
[[ -z "${member_id}" ]] && { echo >&2 "ERROR: member_id undefined. Use -i"; usage 1; }

# Construct Teams API base URL
if [[ "${ENV}" == "prod" ]]; then
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.auth0.com"
else
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.${ENV}.auth0.com"
fi

[[ ${opt_verbose} -eq 1 ]] && echo "GET ${TEAMS_API_URL}/api/v1/members/${member_id}" >&2

curl -s -H "Authorization: Bearer ${api_token}" \
    --url "${TEAMS_API_URL}/api/v1/members/${member_id}" | jq '.'
