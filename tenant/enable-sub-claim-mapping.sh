#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-03-13
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

declare connection='Username-Password-Authentication'
declare sub_source='default'
declare token_type=''
declare resource_type='tenants/settings'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-k connection] [-s source] [-c client_id] [-r resource-server_id] [-i|-a] [-v|-h]
        -e file         # .env file location (default cwd)
        -k connection   # connection name
        -s source       # identity_user_id or default
        -c client_id    # client_id (sets token type to id_token)
        -r resource_id  # resource server id (sets token type to access_token)
        -i              # id_token
        -a              # access_token
        -h|?            # usage
        -v              # verbose

eg,
     $0 -k Username-Password-Authentication -s identity_user_id -i
END
    exit $1
}

while getopts "e:k:c:r:s:iahv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    k) connection=${OPTARG} ;;
    s) sub_source=${OPTARG} ;;
    c) resource_type="clients/${OPTARG}";token_type='id_token' ;;
    r) resource_type="resource-servers/${OPTARG}";token_type='access_token' ;;
    i) token_type='id_token';;
    a) token_type='access_token';;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:tenant_settings"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${token_type}" ]] && { echo >&2 "ERROR: token type undefined.";  usage 1; }
[[ -z "${sub_source}" ]] && { echo >&2 "ERROR: source undefined.";  usage 1; }
[[ -z "${connection}" ]] && { echo >&2 "ERROR: connection undefined.";  usage 1; }


declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare BODY=$(cat <<EOL
{
  "${token_type}": {
    "claims_mapping": {
      "sub": {
        "connection": "${connection}",
        "source": "${sub_source}"
      }
   }
 }
}
EOL
)

curl -s -H "Authorization: Bearer ${access_token}" \
    --request PATCH \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/${resource_type}" | jq .
