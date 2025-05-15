#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2025-05-13
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-n name] [-d description] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -n name         # role name
        -d description  # role description (optional)
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n admin
     $0 -n admin -d "Administrator role with full access"
END
    exit $1
}

declare role_name=''
declare role_description=''
declare -i opt_verbose=0

while getopts "e:a:n:d:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    n) role_name=${OPTARG} ;;
    d) role_description=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:roles"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

[[ -z "${role_name}" ]] && { echo >&2 "ERROR: role name undefined."; usage 1; }

# Construct description JSON if provided
description_text=""
if [[ -n "${role_description}" ]]; then
    description_text=", \"description\": \"${role_description}\""
fi

declare BODY=$(cat <<EOL
{
  "name": "${role_name}"${description_text}
}
EOL
)

if [[ ${opt_verbose} -eq 1 ]]; then
    echo "Request body: ${BODY}"
fi

curl -s --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/roles" | jq '.'

echo