#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2025-05-30
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
# Reference: https://auth0.com/docs/authenticate/single-sign-on/native-to-web/configure-implement-native-to-web
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i client_id] [-m auth_methods] [-b binding] [-d] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # client_id
        -m methods      # allowed_authentication_methods. comma separated (allowed values: "cookie", "query")
        -b binding      # enforce_device_binding: ip, none, asn (default: none)
        -d              # disable can_create_session_transfer_token
        -h|?            # usage
        -v              # verbose

eg,
     # Native apps: use -b and/or -d parameters
     $0 -i 62qDW3H3goXmyJTvpzQzMFGLpVGAJ1Qh -b ip
     $0 -i 62qDW3H3goXmyJTvpzQzMFGLpVGAJ1Qh -d

     # Web apps: use -m parameter
     $0 -i VJIEWAptlFWokl2pRC2ptswic1jCGoEC -m cookie,query
END
    exit $1
}

declare client_id=''
declare auth_methods='cookie,query'
declare device_binding='none'
declare can_create=true
declare opt_verbose=0
declare auth_methods_provided=false

while getopts "e:a:i:m:b:dhv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) client_id=${OPTARG} ;;
    m) auth_methods=${OPTARG}; auth_methods_provided=true ;;
    b) device_binding=${OPTARG} ;;
    d) can_create=false ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPES=("update:clients") # Either of these scopes would do
[[ " $AVAILABLE_SCOPES " == *" ${EXPECTED_SCOPES[0]} "* || " $AVAILABLE_SCOPES " == *" ${EXPECTED_SCOPES[1]} "*  ]] \
    || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected (any of): '${EXPECTED_SCOPES[*]}', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined."; usage 1; }

# Validate device_binding
if [[ "${device_binding}" != "ip" && "${device_binding}" != "none" && "${device_binding}" != "asn" ]]; then
    echo >&2 "ERROR: enforce_device_binding must be one of: ip, none, asn"
    usage 1
fi

# Format auth_methods for JSON
readonly auth_methods_array=$(echo "${auth_methods}" | tr ',' '\n' | while read method; do
  echo "      \"${method}\""
done | paste -sd, -)

# Determine payload format based on input parameters
# If auth_methods is explicitly provided, use Format 2 (web apps)
# Otherwise, use Format 1 (native apps)
if [[ "${auth_methods_provided}" == "true" ]]; then
    # Format 2: web apps - allowed_authentication_methods with cookie or query
    declare BODY=$(cat <<EOL
{
  "session_transfer": {
    "allowed_authentication_methods": [
${auth_methods_array}
    ]
  }
}
EOL
    )
else
    # Format 1: native apps - only can_create_session_transfer_token and enforce_device_binding
    declare BODY=$(cat <<EOL
{
  "session_transfer": {
    "can_create_session_transfer_token": ${can_create},
    "enforce_device_binding": "${device_binding}"
  }
}
EOL
    )
fi

if [[ ${opt_verbose} ]]; then
    echo $BODY
fi

curl -s --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/clients/${client_id}"

echo
