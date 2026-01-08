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
USAGE: $0 [-e env] [-a api_token] [-t team_slug] [-n tenant_name] [-m admin_email] [-r region] [-y environment_type] [-v|-h]
        -e env        # Environment (default: prod). Use 'prod' for teams.auth0.com, or specify env like 'sus' for teams.sus.auth0.com
        -a token      # API access_token (opaque token, not JWT)
        -t slug       # Team slug
        -n name       # Tenant name (3-63 chars, lowercase, alphanumeric and dashes, no leading/trailing dashes)
        -m email      # Admin email (must be a team member)
        -r region     # Public Cloud region: us | eu | au | jp | ca | uk
        -y type       # Environment type: development (default) | production | staging
        -h|?          # usage
        -v            # verbose

eg,
     $0 -t my-team -n acme-development -m admin@company.com -r us
     $0 -e sus -n acme-prod -m admin@company.com -r eu -y production
END
    exit $1
}

declare api_token=''
declare TEAM_SLUG=''
declare tenant_name=''
declare admin_email=''
declare region=''
declare environment_type='development'
declare ENV='prod'

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:a:t:n:m:r:y:hv?" opt; do
    case ${opt} in
    e) ENV=${OPTARG} ;;
    a) api_token=${OPTARG} ;;
    t) TEAM_SLUG=${OPTARG} ;;
    n) tenant_name=${OPTARG} ;;
    m) admin_email=${OPTARG} ;;
    r) region=${OPTARG} ;;
    y) environment_type=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

# Basic validation (no JWT decoding for opaque tokens)
[[ -z "${api_token}" ]] && { echo >&2 "ERROR: api_token undefined. Use -a or set api_token in .env"; usage 1; }
[[ -z "${TEAM_SLUG}" ]] && { echo >&2 "ERROR: TEAM_SLUG undefined. Use -t or set TEAM_SLUG in .env"; usage 1; }
[[ -z "${admin_email}" ]] && { echo >&2 "ERROR: admin_email undefined. Use -m"; usage 1; }
[[ -z "${region}" ]] && { echo >&2 "ERROR: region undefined. Use -r (us, eu, au, jp, ca, uk)"; usage 1; }

# Construct Teams API base URL
if [[ "${ENV}" == "prod" ]]; then
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.auth0.com"
else
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.${ENV}.auth0.com"
fi

# Optional tenant_name field
declare tenant_name_field=''
[[ -n "${tenant_name}" ]] && tenant_name_field="\"tenant_name\": \"${tenant_name}\","

# Construct request body for Public Cloud
declare BODY=$(cat <<EOL
{
  ${tenant_name_field}
  "admin_email": "${admin_email}",
  "region": "${region}",
  "environment_type": "${environment_type}"
}
EOL
)

curl -s --request POST \
    -H "Authorization: Bearer ${api_token}" \
    -H "Content-Type: application/json" \
    --url "${TEAMS_API_URL}/api/tenants" \
    --data "${BODY}" | jq '.'
