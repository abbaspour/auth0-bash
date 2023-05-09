#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-05-08
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################


set -eo pipefail
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-n name] [-t type] [-i client_id] [-p PEM] [-c callbacks] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -n name         # client name (e.g. "My Client")
        -t type         # credential type: public_key
        -i client_id    # client_id (if accept_client_id_on_creation is on)
        -p file         # public key PEM file
        -g algorithm    # Can be one of RS256, RS384, PS256. If not specified, RS256 will be used.
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n "My key" -p public-key.pem -i c123
END
  exit $1
}

declare client_id=''
declare credential_name=''
declare credential_type='public_key'
declare public_key_file=''
declare algorithm='RS256'

while getopts "e:a:n:t:i:p:g:hv?" opt; do
  case ${opt} in
  e) source ${OPTARG} ;;
  a) access_token=${OPTARG} ;;
  n) credential_name=${OPTARG} ;;
  t) credential_type=${OPTARG} ;;
  i) client_id="${OPTARG}";;
  p) public_key_file=${OPTARG} ;;
  g) algorithm=${OPTARG} ;;
  v) set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:client_credentials"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined."; usage 1; }
[[ -z "${public_key_file}" ]] && { echo >&2 "ERROR: public_key_file undefined."; usage 1; }
[[ ! -f "${public_key_file}" ]] && { echo >&2 "ERROR: public_key_file not found: ${public_key_file}"; usage 1; }

[[ -z "${credential_name}" ]] && credential_name=$(basename "${public_key_file}" .pem)

readonly credential_public_key=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "${public_key_file}")

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

declare BODY=$(cat <<EOL
{
  "credential_type": "${credential_type}",
  "name": "${credential_name}",
  "pem": "${credential_public_key}",
  "alg": "${algorithm}"
}
EOL
)

#  "parse_expiry_from_cert": true

curl -s -k --request POST \
  -H "Authorization: Bearer ${access_token}" \
  --data "${BODY}" \
  --header 'content-type: application/json' \
  --url "${AUTH0_DOMAIN_URL}api/v2/clients/${client_id}/credentials" | jq .
