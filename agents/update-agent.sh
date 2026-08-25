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
USAGE: $0 [-e env] [-a access_token] [-i agent_id] [-n name] [-m k1:v1,k2:v2] [-M] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # access_token. default from environment variable
        -i agent_id    # agent id (required)
        -n name        # new agent name (optional)
        -m key:value   # metadata key:value pairs to set (optional)
        -M             # clear all metadata (sends metadata: null; overrides -m)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -i agent_0123456789 -n "Renamed Agent"
     $0 -i agent_0123456789 -m team:platform,tier:2
     $0 -i agent_0123456789 -M
END
  exit $1
}

declare agent_id=''
declare agent_name=''
declare metadata=''
declare -i opt_clear_metadata=0
declare -i opt_verbose=0

while getopts "e:a:i:n:m:Mhv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  a) access_token=${OPTARG} ;;
  i) agent_id=${OPTARG} ;;
  n) agent_name=${OPTARG} ;;
  m) metadata=${OPTARG} ;;
  M) opt_clear_metadata=1 ;;
  v) opt_verbose=1 ;; #set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${agent_id}" ]] && { echo >&2 "ERROR: agent_id undefined. Use -i to specify agent_id"; usage 1; }
[[ -z "${agent_name}" && -z "${metadata}" && ${opt_clear_metadata} -eq 0 ]] && { echo >&2 "ERROR: nothing to update. Use -n and/or -m/-M"; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:agents"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<< "${access_token}")

declare -a fields=()
[[ -n "${agent_name}" ]] && fields+=("\"name\": \"${agent_name}\"")

if [[ ${opt_clear_metadata} -eq 1 ]]; then
  fields+=("\"metadata\": null")
elif [[ -n "${metadata}" ]]; then
  declare pairs=''
  for kv in $(echo "${metadata}" | tr ',' ' '); do
    pairs+=$(echo "${kv}" | awk -F: '{printf("\"%s\":\"%s\",", $1, $2)}')
  done
  pairs=${pairs%?}
  fields+=("\"metadata\": { ${pairs} }")
fi

declare joined_fields=$(printf ",%s" "${fields[@]}")
joined_fields=${joined_fields#,}

declare BODY="{ ${joined_fields} }"

[[ ${opt_verbose} -eq 1 ]] && echo "${BODY}" >&2

curl -s --request PATCH \
  -H "Authorization: Bearer ${access_token}" \
  --data "${BODY}" \
  --header 'content-type: application/json' \
  --url "${AUTH0_DOMAIN_URL}api/v2/agents/${agent_id}" | jq '.'
