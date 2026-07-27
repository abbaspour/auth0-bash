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
USAGE: $0 [-e env] [-a access_token] [-k take] [-n next] [-S since] [-U until] [-T type] [-s status] [-v|-h]
        -e file       # .env file location (default cwd)
        -a token      # access_token. default from environment variable
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
     $0
     $0 -k 20 -S 2026-01-01T00:00:00Z
     $0 -T "Tenant Activity" -s Success
     $0 -n <cursor>
END
    exit $1
}

declare take=''
declare next=''
declare since=''
declare until=''
declare type=''
declare status=''
declare -i opt_verbose=0

while getopts "e:a:k:n:S:U:T:s:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
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

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:team_activity"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r TEAMS_API_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .aud | if type == "array" then .[0] else . end | rtrimstr("/api/")' <<< "${access_token}")

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

[[ ${opt_verbose} -eq 1 ]] && echo "GET ${url}" >&2

curl -s -H "Authorization: Bearer ${access_token}" \
    --url "${url}" | jq '.'
