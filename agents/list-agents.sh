#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-08-25
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-n from] [-k take] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -n from     # pagination cursor (value of 'next' from previous response)
        -k take     # number of results per page (1-100, default 50)
        -h|?        # usage
        -v          # verbose

eg,
     $0
     $0 -k 20
     $0 -n eyJpZCI6IjEyMyJ9
END
  exit $1
}

declare from=''
declare take=''
declare -i opt_verbose=0

while getopts "e:a:n:k:hv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  a) access_token=${OPTARG} ;;
  n) from=${OPTARG} ;;
  k) take=${OPTARG} ;;
  v) opt_verbose=1 ;; #set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:agents"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<< "${access_token}")

declare -a args=()
[[ -n "${from}" ]] && args+=("--data-urlencode" "from=${from}")
[[ -n "${take}" ]] && args+=("--data-urlencode" "take=${take}")

[[ ${opt_verbose} -eq 1 ]] && echo "GET ${AUTH0_DOMAIN_URL}api/v2/agents" >&2

curl -s --get -H "Authorization: Bearer ${access_token}" \
  "${args[@]}" \
  --url "${AUTH0_DOMAIN_URL}api/v2/agents" | jq '.'
