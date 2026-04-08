#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-c custom_ip_header] [-t tls_policy] [-k key] [-s value] [-m|-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # custom_domain_id
        -c header       # custom ip header
        -t policy       # TLS policy (recommended or compatible)
        -k key          # metadata key
        -s value        # metadata value
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i cd_1sVW7q9gnNeAYFsu -c true-client-ip
     $0 -i cd_1sVW7q9gnNeAYFsu -k environment -s production
END
    exit $1
}

declare id=''
declare custom_client_ip_header_text=''
declare tls_policy_text=''
declare metadata_key=''
declare metadata_value=''
declare domain_metadata_text=''
declare -i opt_verbose=0

while getopts "e:a:i:c:t:k:s:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) id=${OPTARG} ;;
    c) custom_client_ip_header_text="\"custom_client_ip_header\": \"${OPTARG}\"" ;;
    t) tls_policy_text="\"tls_policy\": \"${OPTARG}\"" ;;
    k) metadata_key=${OPTARG} ;;
    s) metadata_value=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:custom_domains"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<< "${access_token}")
[[ -z "${id}" ]] && { echo >&2 "ERROR: custom_domain id undefined."; usage 1; }

# Construct domain_metadata JSON if both key and value are provided
if [[ -n "${metadata_key}" && -n "${metadata_value}" ]]; then
    domain_metadata_text="\"domain_metadata\": { \"${metadata_key}\": \"${metadata_value}\" }"
fi

# Set delimiters between JSON fields
delimiter1=''
delimiter2=''

# Set delimiter between custom_client_ip_header and tls_policy
[[ -n "${custom_client_ip_header_text}" && -n "${tls_policy_text}" ]] && delimiter1=', '

# Set delimiter between tls_policy and domain_metadata
[[ -n "${tls_policy_text}" && -n "${domain_metadata_text}" ]] && delimiter2=', '

# Set delimiter between custom_client_ip_header and domain_metadata if tls_policy is empty
[[ -n "${custom_client_ip_header_text}" && -n "${domain_metadata_text}" && -z "${tls_policy_text}" ]] && delimiter1=', '

declare BODY=$(cat <<EOL
{
  ${custom_client_ip_header_text}
  ${delimiter1}
  ${tls_policy_text}
  ${delimiter2}
  ${domain_metadata_text}
}
EOL
)

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/custom-domains/${id}"

echo
