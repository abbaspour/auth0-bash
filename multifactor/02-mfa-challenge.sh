#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare AUTH0_SCOPE='openid profile email'
declare AUTH0_CONNECTION='Username-Password-Authentication'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-x client_secret] [-m mfa_token] [-a authenticator_type] [-i authenticator_id]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -x secret      # Auth0 client secret
        -m token       # MFA token
        -a type        # authenticator type: otp, oob
        -i id          # authenticator_id
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -m "\${mfa_token}" -a otp
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CLIENT_SECRET=''
declare authenticator_type=''
declare authenticator_id=''

declare opt_verbose=0

while getopts "e:t:d:c:x:m:a:i:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    x) AUTH0_CLIENT_SECRET=${OPTARG} ;;
    m) mfa_token=${OPTARG} ;;
    a) authenticator_type=${OPTARG} ;;
    i) authenticator_id=${OPTARG} ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined";  usage 1; }

[[ -z "${mfa_token}" ]] && { echo >&2 "ERROR: mfa_token undefined";  usage 1; }

[[ -z "${authenticator_type}" ]] && { echo >&2 "ERROR: authenticator_type undefined";  usage 1; }

[[ -z "${authenticator_id}" ]] && { echo >&2 "ERROR: authenticator_id undefined";  usage 1; }


declare secret=''
[[ -n "${AUTH0_CLIENT_SECRET}" ]] && secret="\"client_secret\": \"${AUTH0_CLIENT_SECRET}\","

declare BODY=$(cat <<EOL
{
    "client_id": "${AUTH0_CLIENT_ID}",
    ${secret}
    "challenge_type": "${authenticator_type}",
    "authenticator_id": "${authenticator_id}",
    "mfa_token": "${mfa_token}"
}
EOL
)

declare response_json=$(curl -s --header 'content-type: application/json' -d "${BODY}" https://${AUTH0_DOMAIN}/mfa/challenge)

if [ "${authenticator_type}" == "oob" ]; then
    oob_code=$(echo "${response_json}" | jq -r '.oob_code')
    echo "export oob_code=\"${oob_code}\""
fi
