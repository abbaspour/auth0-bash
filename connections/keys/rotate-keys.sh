#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-10-07
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i connection_id] [-s signing_alg|-n encryption_alg] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # connection_id
        -s alg      # rotate the signing key with this algorithm (default key_use when neither -s nor -n given)
                    #   allowed: RS256 RS384 RS512 PS256 PS384 ES256 ES384
        -n alg      # rotate the encryption key with this algorithm
                    #   allowed: RSA-OAEP-256 RSA-OAEP-384 RSA-OAEP-512 ECDH-ES ECDH-ES+A128KW ECDH-ES+A192KW ECDH-ES+A256KW
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i con_XXXXXXXXXXXXXXXX -s RS256
     $0 -i con_XXXXXXXXXXXXXXXX -n RSA-OAEP-256
END
    exit $1
}

declare connection_id=''
declare signing_alg=''
declare encryption_alg=''

while getopts "e:a:i:s:n:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) connection_id=${OPTARG} ;;
    s) signing_alg=${OPTARG} ;;
    n) encryption_alg=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }

[[ -z "${connection_id}" ]] && {  echo >&2 "ERROR: connection_id undefined." ;  usage 1; }

[[ -n "${signing_alg}" && -n "${encryption_alg}" ]] && { echo >&2 "ERROR: -s and -n are mutually exclusive."; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -ra EXPECTED_SCOPES=("create:connections_keys" "update:connections_keys")
for EXPECTED_SCOPE in "${EXPECTED_SCOPES[@]}"; do
    [[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }
done

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<< "${access_token}")

if [[ -n "${encryption_alg}" ]]; then
    declare BODY=$(cat <<EOL
{
  "key_use": "encryption",
  "encryption_alg": "${encryption_alg}"
}
EOL
)
else
    declare BODY=$(cat <<EOL
{
  "key_use": "signing"$( [[ -n "${signing_alg}" ]] && echo ",
  \"signing_alg\": \"${signing_alg}\"" )
}
EOL
)
fi

curl --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}/keys/rotate" | jq '.'
