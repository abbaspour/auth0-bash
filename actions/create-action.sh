#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-f file] [-T trigger_id] [-n name] [-r runtime]  [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -f file         # Action script file
        -T trigger_id   # trigger id. eg: post-login, pre-user-registration
        -n name         # action name
        -r runtime      # Node runtime. (defaults to node16)
        -h|?            # usage
        -v              # verbose

eg,
     $0 -f empty-actions/post-login.js -T post-login -n "New action"
END
    exit $1
}

declare script_file=''
declare trigger_id=''
declare action_name=''
declare runtime='node16'

while getopts "e:a:f:T:n:r:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    f) script_file=${OPTARG} ;;
    T) trigger_id=${OPTARG} ;;
    n) action_name=${OPTARG} ;;
    r) runtime=${OPTARG} ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:actions"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

[[ -z "${action_name}" ]] && { echo >&2 "ERROR: action_name undefined."; usage 1; }
[[ -z "${trigger_id}" ]] && { echo >&2 "ERROR: trigger_id undefined."; usage 1; }
[[ -z "${script_file}" ]] && { echo >&2 "ERROR: script_file undefined."; usage 1; }
[[ -f "${script_file}" ]] || { echo >&2 "ERROR: script_file missing: ${script_file}"; usage 1; }

declare script_single_line=$(sed 's/$/\\n/' ${script_file} | tr -d '\n')

declare BODY=$(cat <<EOL
{
  "name": "${action_name}",
  "supported_triggers": [
    {
      "id": "${trigger_id}",
      "version": "v3"
    }
  ],
  "code": "${script_single_line}",
  "runtime": "${runtime}"
}
EOL
)
echo "$BODY"

curl -s -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/actions/actions \
    -H 'content-type: application/json' \
    --data "${BODY}" | jq .
