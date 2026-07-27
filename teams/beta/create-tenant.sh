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
USAGE: $0 [-e env] [-a api_token] [-t team_slug] [-n tenant_name] [-m admin_email] (-l locality | -p private_env) [-T environment_tag] [-v|-h]
        -e env        # Environment (default: prod). Use 'prod' for teams.auth0.com, or specify env like 'sus' for teams.sus.auth0.com
        -a token      # API access_token (opaque token, not JWT)
        -t slug       # Team slug
        -n name       # Tenant name (optional; auto-generated if omitted)
        -m email      # Admin email (must be a team member)
        -l locality   # Public Cloud locality: us | eu | au | jp | ca | uk  [mutually exclusive with -p]
        -p env        # Private Cloud environment name (e.g., acme-dev)     [mutually exclusive with -l]
        -T tag        # Environment tag (public cloud only): development (default) | production | staging
        -h|?          # usage
        -v            # verbose

eg,
     $0 -t my-team -n acme-dev -m admin@company.com -l us
     $0 -t my-team -n acme-prod -m admin@company.com -l eu -T production
     $0 -t my-team -n acme-private -m admin@company.com -p acme-dev
END
    exit $1
}

declare api_token=''
declare TEAM_SLUG=''
declare tenant_name=''
declare admin_email=''
declare locality=''
declare private_env=''
declare environment_tag='development'
declare ENV='prod'

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:a:t:n:m:l:p:T:hv?" opt; do
    case ${opt} in
    e) ENV=${OPTARG} ;;
    a) api_token=${OPTARG} ;;
    t) TEAM_SLUG=${OPTARG} ;;
    n) tenant_name=${OPTARG} ;;
    m) admin_email=${OPTARG} ;;
    l) locality=${OPTARG} ;;
    p) private_env=${OPTARG} ;;
    T) environment_tag=${OPTARG} ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${api_token}" ]] && { echo >&2 "ERROR: api_token undefined. Use -a or set api_token in .env"; usage 1; }
[[ -z "${TEAM_SLUG}" ]] && { echo >&2 "ERROR: TEAM_SLUG undefined. Use -t or set TEAM_SLUG in .env"; usage 1; }
[[ -z "${admin_email}" ]] && { echo >&2 "ERROR: admin_email undefined. Use -m"; usage 1; }
[[ -z "${locality}" && -z "${private_env}" ]] && { echo >&2 "ERROR: specify -l locality (public cloud) or -p environment (private cloud)"; usage 1; }
[[ -n "${locality}" && -n "${private_env}" ]] && { echo >&2 "ERROR: -l and -p are mutually exclusive"; usage 1; }

if [[ "${ENV}" == "prod" ]]; then
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.auth0.com"
else
    declare -r TEAMS_API_URL="https://${TEAM_SLUG}.teams.${ENV}.auth0.com"
fi

declare tenant_name_field=''
[[ -n "${tenant_name}" ]] && tenant_name_field="\"tenant_name\": \"${tenant_name}\","

declare BODY
if [[ -n "${locality}" ]]; then
    BODY=$(cat <<EOL
{
  ${tenant_name_field}
  "admin_email": "${admin_email}",
  "locality": "${locality}",
  "environment_tag": "${environment_tag}"
}
EOL
)
else
    BODY=$(cat <<EOL
{
  ${tenant_name_field}
  "admin_email": "${admin_email}",
  "environment": "${private_env}"
}
EOL
)
fi

[[ -n "${opt_verbose}" ]] && echo "POST ${TEAMS_API_URL}/api/tenants" >&2
[[ -n "${opt_verbose}" ]] && echo "${BODY}" >&2

curl -s --request POST \
    -H "Authorization: Bearer ${api_token}" \
    -H "Content-Type: application/json" \
    --url "${TEAMS_API_URL}/api/tenants" \
    --data "${BODY}" | jq '.'
