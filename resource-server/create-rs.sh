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
USAGE: $0 [-e env] [-a access_token] [-i identifier] [-n name] [-s scope] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i identifer    # API identifier (e.g. my.api)
        -n name         # API name (e.g. "My API")
        -s scopes       # comma separated scopes
        -p policy       # consent policy, null or 'transactional-authorization-with-mfa'
        -d details      # authorization details types comma separated: e.g. payment_initiation,money_transfer
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i my.api -n "My API" -s read:data,write:data
END
    exit $1
}

declare api_identifier=''
declare api_name=''
declare api_scopes=''
declare consent_policy_str=''

while getopts "e:a:i:n:s:p:d:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) api_identifier=${OPTARG} ;;
    n) api_name=${OPTARG} ;;
    s) api_scopes=${OPTARG} ;;
    p) consent_policy_str="\"consent_policy\":\"${OPTARG}\"," ;;
    d) authorization_details=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:resource_servers"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${api_identifier}" ]] && { echo >&2 "ERROR: api_identifier undefined.";  usage 1; }

[[ -z "${api_name}" ]] && { echo >&2 "ERROR: api_name undefined.";  usage 1; }


declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

for s in $(echo "${api_scopes}" | tr ',' ' '); do
    scopes+="{\"value\":\"${s}\"},"
done
scopes=${scopes%?}

for s in $(echo "${authorization_details}" | tr ',' ' '); do
    types+="{\"type\":\"${s}\"},"
done
types=${types%?}

declare BODY=$(cat <<EOL
{
  "identifier": "${api_identifier}",
  "name": "${api_name}",
  ${consent_policy_str}
  "authorization_details": [ ${types} ],
  "scopes": [ ${scopes} ]
}
EOL
)

curl -k --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/resource-servers
