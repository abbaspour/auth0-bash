#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -euo pipefail

which curl >/dev/null || {
    echo >&2 "error: curl not found"
    exit 3
}
which jq >/dev/null || {
    echo >&2 "error: jq not found"
    exit 3
}

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i connection_id] [-f js_file] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # connection_id
        -t type     # script type: login, create, get_user, verify, change_password, change_email, fetchUserProfile
        -f file     # script JS file
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
    exit $1
}

declare script_type=''
declare js_file=''
declare connection_id=''

while getopts "e:a:i:t:f:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) connection_id=${OPTARG} ;;
    t) script_type=${OPTARG} ;;
    f) js_file=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:connections"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${connection_id}" ]] && { echo >&2 "ERROR: connection_id undefined."; usage 1; }
[[ -z "${script_type}" ]] && { echo >&2 "ERROR: script_type undefined."; usage 1; }
[[ -z "${js_file}" ]] && { echo >&2 "ERROR: js_file undefined."; usage 1; }
[[ -f "${js_file}" ]] || { echo >&2 "ERROR: js_file missing: ${js_file}"; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare -r script_single_line=$(sed 's/$/\\\\n/' ${js_file} | tr -d '\n')

declare BODY=$(
    cat <<EOL
{
 "options" : {
  "scripts": {
   "${script_type}": "${script_single_line}"
  }
 }
}
EOL
)

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id} \
    --header 'content-type: application/json' \
    --data "${BODY}"
