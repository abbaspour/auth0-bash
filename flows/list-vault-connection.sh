#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2025-09-08
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -euo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

# shellcheck disable=SC2034
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-d domain] [-p|-h|-v]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -d domain   # Auth0 domain (e.g., your-tenant.eu.auth0.com). If omitted, derived from token's iss
        -i id       # vault connection id
        -p          # pretty print
        -h|?        # usage
        -v          # verbose

eg,
     $0
     $0 -p
END
    exit $1
}

pp=0
JQ_SCRIPT='.'
declare uri='' # appended to base path when -i is provided

while getopts "e:a:d:i:phv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    i) uri="/${OPTARG}" ;;
    p)
        pp=1
        # Attempt a reasonable pretty print; fall back fields are id, name, status if present
        JQ_SCRIPT='def f(x): if x==null then "" else x end; (if type=="array" then . else [.] end)[] | "\(.id)\t\(f(.name))\t\(f(.status))"'
        ;;
    v) opt_verbose=1 ;; # set -x (not enabling automatically to keep output clean)
    h|?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token:-}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' or use -a"; usage 1; }

# Validate scope contains read:flows_vault_connections
AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
EXPECTED_SCOPE="read:flows_vault_connections"
[[ " ${AVAILABLE_SCOPES} " == *" ${EXPECTED_SCOPE} "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '${EXPECTED_SCOPE}', Available: '${AVAILABLE_SCOPES}'"; exit 1; }

# Determine domain URL
if [[ -z "${AUTH0_DOMAIN:-}" ]]; then
  AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")
else
  # ensure scheme
  if [[ "${AUTH0_DOMAIN}" == http*://* ]]; then
    AUTH0_DOMAIN_URL="${AUTH0_DOMAIN%/}/"
  else
    AUTH0_DOMAIN_URL="https://${AUTH0_DOMAIN%/}/"
  fi
fi

BASE_PATH="api/v2/flows/vault/connections"

if [[ ${pp} -eq 1 ]]; then
  echo -e "ID\tName\tStatus"
fi

curl -sS -H "Authorization: Bearer ${access_token}" \
  --url "${AUTH0_DOMAIN_URL}${BASE_PATH}${uri}" | jq -r "${JQ_SCRIPT}"
