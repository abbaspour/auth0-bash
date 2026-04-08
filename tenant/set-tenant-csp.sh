#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-03-17
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

declare policy_file=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-f file] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -f file     # JSON file containing content_security_policy object
        -h|?        # usage
        -v          # verbose

eg,
     $0 -f csp-policy.json
END
    exit $1
}

while getopts "e:a:f:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    f) policy_file=${OPTARG} ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE'"; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:tenant_settings"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${policy_file}" ]] && { echo >&2 "ERROR: policy file undefined. Use -f to specify a JSON file."; usage 1; }
[[ -f "${policy_file}" ]] || { echo >&2 "ERROR: policy file not found: ${policy_file}"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<< "${access_token}")

declare BODY
BODY=$(jq -n --slurpfile csp "${policy_file}" '{"security_headers":{"content_security_policy":$csp[0]}}')

curl -s -H "Authorization: Bearer ${access_token}" \
    --request PATCH \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/tenants/settings"

echo
