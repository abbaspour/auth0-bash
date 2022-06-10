#!/usr/bin/env bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-c custom_ip_header] [-t tls_policy] [-m|-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # custom_domain_id
        -c header       # custom ip header
        -t policy       # TLS policy (recommended or compatible)
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i cd_1sVW7q9gnNeAYFsu -c true-client-ip
END
    exit $1
}

declare id=''
declare custom_client_ip_header_text=''
declare tls_policy_text=''
declare delimiter=''
declare -i opt_verbose=0

while getopts "e:a:i:c:t:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) id=${OPTARG} ;;
    c) custom_client_ip_header_text="\"custom_client_ip_header\": \"${OPTARG}\"" ;;
    t) tls_policy_text="\"tls_policy\": \"${OPTARG}\"" ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:custom_domains"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")
[[ -z "${id}" ]] && { echo >&2 "ERROR: custom_domain id undefined."; usage 1; }

[[ -n "${custom_client_ip_header_text}" && -n "${tls_policy_text}" ]] && delimiter=', '

declare BODY=$( cat <<EOL
{
  ${custom_client_ip_header_text}
  ${delimiter}
  ${tls_policy_text}
}
EOL
)

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/custom-domains/${id}"

echo
