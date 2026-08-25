#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-08-25
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -euo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-n name] [-x external_agent_id] [-m k1:v1,k2:v2] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -n name         # agent name (required)
        -x id           # external_agent_id, immutable, unique per tenant (optional)
        -m key:value    # metadata key:value pairs (optional)
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n "My Agent"
     $0 -n "My Agent" -x ext-agent-1 -m team:platform,tier:1
END
  exit $1
}

declare agent_name=''
declare external_agent_id=''
declare metadata=''
declare -i opt_verbose=0

while getopts "e:a:n:x:m:hv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  a) access_token=${OPTARG} ;;
  n) agent_name=${OPTARG} ;;
  x) external_agent_id=${OPTARG} ;;
  m) metadata=${OPTARG} ;;
  v) opt_verbose=1 ;; #set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${agent_name}" ]] && { echo >&2 "ERROR: name undefined. Use -n to specify agent name"; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:agents"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<< "${access_token}")

declare external_agent_id_field=''
[[ -n "${external_agent_id}" ]] && external_agent_id_field="\"external_agent_id\": \"${external_agent_id}\","

declare metadata_field=''
if [[ -n "${metadata}" ]]; then
  declare pairs=''
  for kv in $(echo "${metadata}" | tr ',' ' '); do
    pairs+=$(echo "${kv}" | awk -F: '{printf("\"%s\":\"%s\",", $1, $2)}')
  done
  pairs=${pairs%?}
  metadata_field="\"metadata\": { ${pairs} },"
fi

declare BODY=$(cat <<EOL
{
  ${external_agent_id_field}
  ${metadata_field}
  "name": "${agent_name}"
}
EOL
)

[[ ${opt_verbose} -eq 1 ]] && echo "${BODY}" >&2

curl -s --request POST \
  -H "Authorization: Bearer ${access_token}" \
  --data "${BODY}" \
  --header 'content-type: application/json' \
  --url "${AUTH0_DOMAIN_URL}api/v2/agents" | jq '.'
