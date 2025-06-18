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
USAGE: $0 [-e env] [-a access_token] [-n domain] [-t type] [-H header] [-k key] [-s value] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -n domain       # domain name (e.g. "auth.example.com")
        -t type         # provisioning type: auth0_managed_certs (default) or self_managed_certs
        -H header       # custom client ip header (optional)
        -k key          # metadata key
        -s value        # metadata value
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n auth.example.com
     $0 -n auth.example.com -t self_managed_certs
     $0 -n auth.example.com -H true-client-ip
     $0 -n auth.example.com -k environment -s production
END
    exit $1
}

declare domain_name=''
declare provisioning_type='auth0_managed_certs'
declare custom_client_ip_header=''
declare metadata_key=''
declare metadata_value=''
declare domain_metadata_text=''
declare -i opt_verbose=0

while getopts "e:a:n:t:H:k:s:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    n) domain_name=${OPTARG} ;;
    t) provisioning_type=${OPTARG} ;;
    H) custom_client_ip_header=${OPTARG} ;;
    k) metadata_key=${OPTARG} ;;
    s) metadata_value=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:custom_domains"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

[[ -z "${domain_name}" ]] && { echo >&2 "ERROR: domain name undefined."; usage 1; }

# Validate provisioning type
if [[ "${provisioning_type}" != "auth0_managed_certs" && "${provisioning_type}" != "self_managed_certs" ]]; then
    echo >&2 "ERROR: Invalid provisioning type. Must be either 'auth0_managed_certs' or 'self_managed_certs'."
    usage 1
fi

# Construct domain_metadata JSON if both key and value are provided
if [[ -n "${metadata_key}" && -n "${metadata_value}" ]]; then
    domain_metadata_text=", \"domain_metadata\": { \"${metadata_key}\": \"${metadata_value}\" }"
fi

# Construct custom_client_ip_header JSON if provided
custom_client_ip_header_text=""
if [[ -n "${custom_client_ip_header}" ]]; then
    custom_client_ip_header_text=", \"custom_client_ip_header\": \"${custom_client_ip_header}\""
fi

declare BODY=$(cat <<EOL
{
  "domain": "${domain_name}",
  "type": "${provisioning_type}",
  "verification_method": "txt",
  "tls_policy": "recommended"
  ${custom_client_ip_header_text}
  ${domain_metadata_text}
}
EOL
)

if [[ ${opt_verbose} -eq 1 ]]; then
    echo "Request body: ${BODY}"
fi

curl -v --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/custom-domains" | jq '.'

echo