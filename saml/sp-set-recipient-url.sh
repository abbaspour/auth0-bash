#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-08-21
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
#
##########################################################################################

# https://auth0.com/docs/authenticate/protocols/saml/saml-sso-integrations/configure-auth0-saml-service-provider#configure-saml-connection-for-proxy-gateways

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i connection_id] [-r url] [-E] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # connection_id
        -r rsp      # recipient Url
        -E          # erase custom destination Url
        -h|?        # usage
        -v          # verbose

eg,
     $0 -c con_mcjX9wmTo1l7RdGh -r https://my.previous.saml.sp/recipient/url
END
    exit $1
}

declare connection_id=''
declare erase=false
declare recipientUrl=''

while getopts "e:a:i:r:Ehv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) connection_id=${OPTARG} ;;
    r) recipientUrl=${OPTARG} ;;
    E) erase=true ;;
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


readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

declare BODY

if [[ ${erase} == true ]]; then
  BODY=$(curl --silent --request GET \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" \
    --header 'content-type: application/json' | jq "del(.realms, .id, .strategy, .name, .provisioning_ticket_url, .recipientUrl)")
else
  BODY=$(curl --silent --request GET \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" \
    --header 'content-type: application/json' | jq "del(.realms, .id, .strategy, .name, .provisioning_ticket_url) | .options += {\"recipientUrl\": \"${recipientUrl}\" }")
fi

curl -s --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" \
    --data "${BODY}" | jq .
