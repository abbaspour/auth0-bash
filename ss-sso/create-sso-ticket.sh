#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-08-26
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -euo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

# TODO: add enabled_organizations support

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i profile_id] [-n conn_name] [-I connection_id] [-i client_id(s)] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i profile_id   # self-service profile id
        -n name         # connection name (e.g. "my-generic-saml-connection") for creating new connection
        -I connect_id   # connection_id for updating existing connection
        -c client_id(s) # command seperated list of enabled clients
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n "my-ss-sso-connection" -c client1,client2
END
  exit $1
}

declare connection_id_or_name=''
declare enabled_clients=''
declare profile_id=''


while getopts "e:a:n:i:I:c:hv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  a) access_token=${OPTARG} ;;
  i) profile_id=${OPTARG} ;;
  I) connection_id_or_name="\"connection_id\":\"${OPTARG}\"" ;;
  n) connection_id_or_name="\"connection_config\":{\"name\":\"${OPTARG}\"}" ;;
  c) enabled_clients=${OPTARG} ;;
  v) set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${profile_id}" ]] && { echo >&2 "ERROR: profile_id required."; usage 1; }
[[ -z "${connection_id_or_name}" ]] && { echo >&2 "ERROR: connection name or id required."; usage 1; }
[[ -z "${enabled_clients}" ]] && { echo >&2 "ERROR: enabled_client(s) is required."; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:sso_access_tickets"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r client_ids=$(echo "${enabled_clients}" | sed -e 's/,/", "/g')
enabled_clients_str=$(cat <<EOL
"enabled_clients": [
    "${client_ids}"
  ]
EOL
)

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

declare BODY=$(cat <<EOL
{
  ${connection_id_or_name},
  ${enabled_clients_str}
}
EOL
)

curl -s --request POST \
  -H "Authorization: Bearer ${access_token}" \
  --data "${BODY}" \
  --header 'content-type: application/json' \
  --url "${AUTH0_DOMAIN_URL}api/v2/self-service-profiles/${profile_id}/sso-ticket" | jq .ticket


