#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-07-14
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -euo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-c client_id] [-o org_id] [-m email] [-t ttl] [-D domain] [-u result_url] [-r realm] [-v|-h]
        -e file      # .env file location (default cwd)
        -a token     # access_token. default from environment variable
        -i user_id   # user_id (either user_id OR both email and connection_id must be provided)
        -c client_id # client_id
        -o org_id    # (optional) organization ID
        -m email     # email (required if user_id is not provided)
        -t ttl       # time to live in seconds. default is 432000 (5 days)
        -D domain    # (optional) custom domain for auth0-custom-domain header
        -u url       # result URL
        -r realm     # connection_id (required if email is provided)
        -h|?         # usage
        -v           # verbose

eg,
     $0 -i 'auth0|123456789' -c abcdef123456 -t 86400 -u https://example.com/reset
     $0 -c abcdef123456 -m user@example.com -r con_123456789 -t 86400 -u https://example.com/reset
     $0 -c abcdef123456 -m user@example.com -r con_123456789 -t 86400 -u https://example.com/reset -D custom.domain.com
END
    exit $1
}

declare user_id=''
declare client_id=''
declare org_id=''
declare email=''
declare ttl='432000'
declare custom_domain=''
declare result_url=''
declare realm=''

while getopts "e:a:i:c:o:m:t:D:u:r:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) user_id=${OPTARG} ;;
    c) client_id=${OPTARG} ;;
    o) org_id=${OPTARG} ;;
    m) email=${OPTARG} ;;
    t) ttl=${OPTARG} ;;
    D) custom_domain="auth0-custom-domain: ${OPTARG}" ;;
    u) result_url=${OPTARG} ;;
    r) realm=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:user_tickets"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined."; usage 1; }
[[ -z "${result_url}" ]] && { echo >&2 "ERROR: result_url undefined."; usage 1; }

# Validate that either user_id OR both email and connection_id are provided
if [[ -n "${user_id}" && -n "${email}" ]]; then
    echo >&2 "ERROR: Both user_id and email provided. Use either user_id OR email with connection_id."
    usage 1
elif [[ -z "${user_id}" && -z "${email}" ]]; then
    echo >&2 "ERROR: Neither user_id nor email provided. Use either user_id OR email with connection_id."
    usage 1
elif [[ -z "${user_id}" && -z "${realm}" ]]; then
    echo >&2 "ERROR: Email provided without connection_id. When using email, connection_id is required."
    usage 1
fi

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

# Prepare the request body
declare BODY="{\"client_id\":\"${client_id}\",\"ttl_sec\":${ttl},\"result_url\":\"${result_url}\""

# Add user_id or email+connection_id based on what was provided
if [[ -n "${user_id}" ]]; then
    BODY+=",\"user_id\":\"${user_id}\""
else
    BODY+=",\"email\":\"${email}\",\"connection_id\":\"${realm}\""
fi

# Add optional parameters if provided
if [[ -n "${org_id}" ]]; then
    BODY+=",\"organization_id\":\"${org_id}\""
fi

# Close the JSON object
BODY+='}'

# Debug output if verbose mode is enabled
[[ -n "${opt_verbose:-}" ]] && { echo "${BODY}" | jq .; }

# Send the request to the Auth0 API
curl -s --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/tickets/password-change" \
    --header 'content-type: application/json' \
    --header "${custom_domain}" \
    --data "${BODY}" | jq .
