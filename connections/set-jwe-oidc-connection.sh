#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-10-28
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
#
# Enables (or disables) encrypted (JWE) id_token for an OIDC/Okta connection by setting
# options.id_token_encrypted_response_alg and, optionally, options.id_token_encrypted_response_encs.
# api2 provisions the connection's encryption (use: enc) key pair when JWE is enabled; the
# public keys are then published at /oauth/connection/{name}/.well-known/jwks.json
# (see keys/get-jwks.sh).
##########################################################################################

set -ueo pipefail

DIR="${BASH_SOURCE[0]%/*}"
[ "$DIR" = "${BASH_SOURCE[0]}" ] && DIR="."
readonly DIR

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null   || { echo >&2 "error: jq not found";    exit 3; }

readonly ALLOWED_ALGS="RSA-OAEP-256 RSA-OAEP-384 RSA-OAEP-512 ECDH-ES ECDH-ES+A128KW ECDH-ES+A192KW ECDH-ES+A256KW"
readonly ALLOWED_ENCS="A128CBC-HS256 A192CBC-HS384 A256CBC-HS512 A128GCM A192GCM A256GCM"

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i connection_id] [-A alg] [-E encs] [-d] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # access_token. default from environment variable
        -i id          # connection_id
        -A alg         # key management algorithm (default RSA-OAEP-256)
                       #   allowed: ${ALLOWED_ALGS}
        -E encs        # comma separated allowlist of content encryption algorithms (default: any)
                       #   allowed: ${ALLOWED_ENCS}
        -d             # disable JWE id_token (removes both settings)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -i con_XXXXXXXXXXXXXXXX
     $0 -i con_XXXXXXXXXXXXXXXX -A ECDH-ES+A128KW -E A256GCM,A128CBC-HS256
     $0 -i con_XXXXXXXXXXXXXXXX -d
END
    exit "$1"
}

declare access_token="${access_token:-}"
declare connection_id=''
declare alg='RSA-OAEP-256'
declare encs=''
declare -i opt_disable=0
declare -i opt_verbose=0

while getopts ":e:a:i:A:E:dhv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) connection_id=${OPTARG} ;;
    A) alg=${OPTARG} ;;
    E) encs=${OPTARG} ;;
    d) opt_disable=1 ;;
    v) opt_verbose=1 ;; #set -x;;
    h) usage 0 ;;
    \?) [[ "${OPTARG}" == "?" ]] && usage 0
        echo >&2 "ERROR: illegal option -- ${OPTARG}"
        usage 1 ;;
    :) echo >&2 "ERROR: option requires an argument -- ${OPTARG}"; usage 1 ;;
    esac
done

[[ -z "${access_token}" ]]  && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${connection_id}" ]] && { echo >&2 "ERROR: connection_id undefined."; usage 1; }

[[ " ${ALLOWED_ALGS} " == *" ${alg} "* ]] || { echo >&2 "ERROR: unsupported alg: ${alg}"; usage 1; }
for enc in ${encs//,/ }; do
    [[ " ${ALLOWED_ENCS} " == *" ${enc} "* ]] || { echo >&2 "ERROR: unsupported enc: ${enc}"; usage 1; }
done

AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
readonly AVAILABLE_SCOPES
for EXPECTED_SCOPE in read:connections update:connections; do
    [[ " ${AVAILABLE_SCOPES} " == *" ${EXPECTED_SCOPE} "* ]] \
        || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '${EXPECTED_SCOPE}', Available: '${AVAILABLE_SCOPES}'"; exit 1; }
done

AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<< "${access_token}")
readonly AUTH0_DOMAIN_URL

connection=$(curl -s --request GET \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}")
readonly connection

jq -e '.id' <<< "${connection}" >/dev/null 2>&1 \
    || { echo >&2 "ERROR: unable to fetch connection ${connection_id}"; jq . <<< "${connection}" >&2 || echo >&2 "${connection}"; exit 1; }

strategy=$(jq -r '.strategy' <<< "${connection}")
readonly strategy
[[ "${strategy}" == "oidc" || "${strategy}" == "okta" ]] \
    || { echo >&2 "ERROR: JWE id_token is only supported for oidc/okta connections, got strategy: ${strategy}"; exit 1; }

# PATCH replaces .options as a whole, so start from the current options and only change the JWE settings
BODY=$(jq --argjson disable "${opt_disable}" --arg alg "${alg}" --arg encs "${encs}" \
    'del(.realms, .id, .strategy, .name, .provisioning_ticket_url) |
     del(.options.id_token_encrypted_response_alg, .options.id_token_encrypted_response_encs) |
     if $disable == 1 then .
     else
         .options += {"id_token_encrypted_response_alg": $alg} +
             (if $encs != "" then {"id_token_encrypted_response_encs": ($encs | split(","))} else {} end)
     end' <<< "${connection}")
readonly BODY

[[ ${opt_verbose} -eq 1 ]] && jq >&2 '.options | {id_token_encrypted_response_alg, id_token_encrypted_response_encs}' <<< "${BODY}"

curl -s --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}" | jq .
