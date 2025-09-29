#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-01-23
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare user_id=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # mfa_token. default from environment variable
        -t type     # type; "phone" or "email" or "totp" or "webauthn-roaming"
        -n name     # name
        -s secret   # Base32 encoded secret for TOTP generation (min 128b)
        -S secret   # plain secret for TOTP generation (min 128b)
        -p number   # phone number
        -k public   # public key in base64 encoded CBOR format
        -I cred-id  # credential id
        -r rp-id    # relying party id
        -m email    # email
        -h|?        # usage
        -v          # verbose

eg,
     $0 -t phone -p +614000000 -n sms
END
    exit $1
}

declare type=''
declare method_payload=''
declare name_string=''
declare public_key=''
declare rp_id=''
declare key_id=''

while getopts "e:a:t:n:p:m:s:S:k:I:r:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) mfa_token=${OPTARG} ;;
    t) type=${OPTARG} ;;
    n) name_string="\"name\":\"${OPTARG}\", ";;
    p) method_payload="\"oob_channels\": [\"sms\"], \"phone_number\":\"${OPTARG}\"";;
    m) method_payload="\"email\":\"${OPTARG}\"";;
    s) method_payload="\"totp_secret\":\"${OPTARG}\"";;
    S) method_payload="\"totp_secret\":\"$(echo -n ${OPTARG} | base32 -w0)\"";;
    k) public_key="${OPTARG}";;
    I) key_id="${OPTARG}";; # $(echo "${OPTARG}" | tr -d '=');;
    r) rp_id="${OPTARG}";;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${mfa_token}" ]] && { echo >&2 "ERROR: mfa_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${mfa_token}")
declare -r EXPECTED_SCOPE="enroll"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${type}" ]] && { echo >&2 "ERROR: type undefined."; usage 1; }

if [[ "${type}" == "webauthn-roaming" ]]; then
  method_payload="\"public_key\":\"${public_key}\", \"key_id\": \"${key_id}\", \"relying_party_identifier\":\"${rp_id}\""
elif [[ -z "${method_payload}" ]]; then
  echo >&2 "ERROR: authenticator details missing."; usage 1;
fi

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${mfa_token}")

declare BODY=$(cat <<EOL
{
    "authenticator_types": ["${type}"], ${name_string}
    ${method_payload}
}
EOL
)

echo $BODY

curl -s -H "Authorization: Bearer ${mfa_token}" \
    --header 'content-type: application/json' -d "${BODY}" \
    --url "${AUTH0_DOMAIN_URL}mfa/associate" | jq .
