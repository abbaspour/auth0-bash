#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

# https://auth0.com/docs/configure/saml-configuration/saml-sso-integrations/sign-and-encrypt-saml-requests#use-custom-certificate-to-sign-requests

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i connection_id] [-c cert-file] [-p key-file] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # connection_id
        -c cert.pem # certificate PEM file
        -k ley.pem  # private key PEM file
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
    exit $1
}

declare cert_file=''
declare key_file=''
declare connection_id=''

while getopts "e:a:i:c:k:dhv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) connection_id=${OPTARG} ;;
    c) cert_file=${OPTARG} ;;
    k) key_file=${OPTARG} ;;
    v) set -x ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPES=("read:connections" "update:connections") # Both scopes are required
[[ " $AVAILABLE_SCOPES " == *" ${EXPECTED_SCOPES[0]} "* && " $AVAILABLE_SCOPES " == *" ${EXPECTED_SCOPES[1]} "*  ]] \
    || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected (all of): '${EXPECTED_SCOPES[*]}', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${connection_id}" ]] && { echo >&2 "ERROR: connection_id undefined.";  usage 1; }

[[ -z "${cert_file}" ]] && { echo >&2 "ERROR: cert_file undefined.";  usage 1; }

[[ -z "${key_file}" ]] && { echo >&2 "ERROR: key_file undefined.";  usage 1; }

[[ -f "${cert_file}" ]] || { echo >&2 "ERROR: cert_file missing: ${cert_file}";  usage 1; }

[[ -f "${key_file}" ]] || { echo >&2 "ERROR: key_file missing: ${key_file}";  usage 1; }


readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

readonly cert_txt=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "${cert_file}")
readonly key_txt=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "${key_file}")

readonly BODY=$(curl --silent --request GET \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" \
    --header 'content-type: application/json' | jq "del(.realms, .id, .strategy, .name, .provisioning_ticket_url, .options.signing_keys, .options.signing_key) | .options += {\"signing_key\":{\"cert\": \"${cert_txt}\",\"key\": \"${key_txt}\"}}" | jq -r)

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" \
    --data "${BODY}"
