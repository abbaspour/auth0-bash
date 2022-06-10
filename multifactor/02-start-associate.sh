#!/usr/bin/env bash

set -eo pipefail

which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }
which jq > /dev/null || { echo >&2 "error: jq not found"; exit 3; }
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-m mfa_token] [-a authenticator_type] [-n number]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -m token       # MFA token
        -a type        # authenticator type: otp, oob
        -n mobile      # Mobile number for SMS OOB channel
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -m \${mfa_token} -a oob -n +61400000000
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare authenticator_type=''
declare channel_details=''

[[ -f ${DIR}/.env ]] && . "${DIR}"/.env

while getopts "e:t:d:m:a:n:hv?" opt
do
    case ${opt} in
        e) source "${OPTARG}";;
        t) AUTH0_DOMAIN=$(echo "${OPTARG}".auth0.com | tr '@' '.');;
        d) AUTH0_DOMAIN=${OPTARG};;
        m) mfa_token=${OPTARG};;
        a) authenticator_type=${OPTARG};;
        n) authenticator_type='oob'; channel_details=",\"oob_channels\" : [\"sms\"], \"phone_number\": \"${OPTARG}\"";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${mfa_token}" ]] && { echo >&2 "ERROR: mfa_token undefined"; usage 1; }
[[ -z "${authenticator_type}" ]] && { echo >&2 "ERROR: authenticator_type undefined"; usage 1; }


readonly BODY=$(cat <<EOL
{
    "authenticator_types": ["${authenticator_type}"]
    ${channel_details}
}
EOL
)

readonly response_json=$(curl -s -H "Authorization: Bearer ${mfa_token}" --header 'content-type: application/json' -d "${BODY}" "https://${AUTH0_DOMAIN}/mfa/associate")

if [ "${authenticator_type}" == "otp" ]; then
    secret=$(echo "${response_json}" | jq -r '.secret')
    barcode_uri=$(echo "${response_json}" | jq -r '.barcode_uri') echo "secret=\"${secret}\"" echo "barcode_uri=\"${secret}\""
    if [[ $(which qrencode) ]]; then
        qrencode -o qr.png "${barcode_uri}"
        open qr.png
    fi
else 
    oob_code=$(echo "${response_json}" | jq -r '.oob_code') echo "export oob_code=\"${oob_code}\""
fi

