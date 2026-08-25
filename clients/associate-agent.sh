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
USAGE: $0 [-e env] [-a access_token] [-i client_id] [-g agent_id] [-R] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # access_token. default from environment variable
        -i client_id   # client id to associate/dissociate (required)
        -g agent_id    # agent id to associate with the client
        -R             # remove/dissociate the client's current agent (sends agent_id: null)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -i client_123 -g agent_0123456789
     $0 -i client_123 -R
END
  exit $1
}

declare client_id=''
declare agent_id=''
declare -i opt_remove=0
declare -i opt_verbose=0

while getopts "e:a:i:g:Rhv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  a) access_token=${OPTARG} ;;
  i) client_id=${OPTARG} ;;
  g) agent_id=${OPTARG} ;;
  R) opt_remove=1 ;;
  v) opt_verbose=1 ;; #set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined. Use -i to specify client_id"; usage 1; }
[[ -z "${agent_id}" && ${opt_remove} -eq 0 ]] && { echo >&2 "ERROR: nothing to do. Use -g to associate an agent or -R to dissociate"; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:clients"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<< "${access_token}")

if [[ ${opt_remove} -eq 1 ]]; then
  declare BODY='{"agent_id": null}'
else
  declare BODY="{\"agent_id\": \"${agent_id}\"}"
fi

[[ ${opt_verbose} -eq 1 ]] && echo "${BODY}" >&2

curl -s --request PATCH \
  -H "Authorization: Bearer ${access_token}" \
  --data "${BODY}" \
  --header 'content-type: application/json' \
  --url "${AUTH0_DOMAIN_URL}api/v2/clients/${client_id}" | jq '.'
