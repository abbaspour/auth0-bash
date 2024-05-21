#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

# https://auth0.com/docs/configure/saml-configuration/saml-sso-integrations/sign-and-encrypt-saml-requests#use-custom-certificate-to-sign-requests

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-i connection_id] [-a audience] [-v|-h]
        -e file     # .env file location (default cwd)
        -i id       # connection_id
        -a audience # new audience aka entityId
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
    exit $1
}

declare audience=''
declare connection_id=''

while getopts "e:a:i:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    i) connection_id=${OPTARG} ;;
    a) audience=${OPTARG} ;;
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
[[ -z "${audience}" ]] && { echo >&2 "ERROR: audience undefined.";  usage 1; }

readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

readonly BODY=$(curl --silent --request GET \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" \
    --header 'content-type: application/json' | jq "del(.realms, .id, .strategy, .name, .provisioning_ticket_url, .options.signing_keys, .options.signing_key) | .options += {\"entityId\":\"${audience}\"}" | jq -r)

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" \
    --data "${BODY}"
