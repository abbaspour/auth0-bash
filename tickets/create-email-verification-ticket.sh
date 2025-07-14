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
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-c client_id] [-o org_id] [-D domain] [-u result_url] [-t ttl] [-v|-h]
        -e file      # .env file location (default cwd)
        -a token     # access_token. default from environment variable
        -i user_id   # user_id
        -c client_id # client_id
        -o org_id    # (optional) organization ID
        -D domain    # (optional) custom domain for auth0-custom-domain header
        -u url       # result URL
        -t ttl       # (optional) time to live in seconds. default is 432000 (5 days)
        -h|?         # usage
        -v           # verbose

eg,
     $0 -i 'auth0|123456789' -c abcdef123456 -u https://example.com/verify
     $0 -i 'auth0|123456789' -c abcdef123456 -u https://example.com/verify -D custom.domain.com
END
    exit $1
}

declare user_id=''
declare client_id=''
declare org_id=''
declare custom_domain=''
declare result_url=''
declare ttl='432000'

while getopts "e:a:i:c:o:D:u:t:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) user_id=${OPTARG} ;;
    c) client_id=${OPTARG} ;;
    o) org_id=${OPTARG} ;;
    D) custom_domain="auth0-custom-domain: ${OPTARG}" ;;
    u) result_url=${OPTARG} ;;
    t) ttl=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:user_tickets"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${user_id}" ]] && { echo >&2 "ERROR: user_id undefined."; usage 1; }
[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined."; usage 1; }
[[ -z "${result_url}" ]] && { echo >&2 "ERROR: result_url undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

# Prepare the request body
declare BODY="{\"user_id\":\"${user_id}\",\"client_id\":\"${client_id}\",\"result_url\":\"${result_url}\""

# Add optional parameters if provided
if [[ -n "${org_id}" ]]; then
    BODY+=",\"organization_id\":\"${org_id}\""
fi

if [[ -n "${ttl}" ]]; then
    BODY+=",\"ttl_sec\":${ttl}"
fi

# Close the JSON object
BODY+='}'

# Send the request to the Auth0 API
curl -s --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/tickets/email-verification" \
    --header 'content-type: application/json' \
    --header "${custom_domain}" \
    --data "${BODY}" | jq .