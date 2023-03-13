#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

## note:
# this script is using legacy endpoint `/oauth/ro`.
# you should have grant type 'Legacy:RO' and disable 'OIDC Conformant'

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare AUTH0_SCOPE='openid email'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-u email] [-x code] [-p phone_number] [-s scope] [-m|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -x secret      # Auth0 client secret (optional)
        -a audience    # Audience
        -s scopes      # comma separated list of scopes (default is "${AUTH0_SCOPE}")
        -p number      # SMS phone number
        -u email       # Email
        -o code        # OTP code received in SMS or Email
        -m             # Management API audience
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -u user@email.com
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CLIENT_SECRET=''
declare AUTH0_CONNECTION=''

declare username=''
declare otp_code=''
declare opt_mgmnt=''

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:t:d:c:a:x:u:p:s:o:mhv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    x) AUTH0_CLIENT_SECRET=${OPTARG} ;;
    a) AUTH0_AUDIENCE=${OPTARG} ;;
    u) username=${OPTARG}; AUTH0_CONNECTION='email' ;;
    p) username=${OPTARG}; AUTH0_CONNECTION='sms' ;;
    o) otp_code=${OPTARG} ;;
    s) AUTH0_SCOPE=$(echo "${OPTARG}" | tr ',' ' ') ;;
    m) opt_mgmnt=1 ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined";  usage 1; }

[[ -z "${AUTH0_CONNECTION}" ]] && { echo >&2 "ERROR: AUTH0_CONNECTION undefined. select 'sms' or 'email'";  usage 1; }

[[ -z "${otp_code}" ]] && { echo >&2 "ERROR: otp_code undefined.";  usage 1; }

[[ -z "${username}" ]] && { echo >&2 "ERROR: email or phone_number undefined.";  usage 1; }


[[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/" # audience is unsupported in OTP (23/08/18)

declare secret=''
[[ -n "${AUTH0_CLIENT_SECRET}" ]] && secret="\"client_secret\":\"${AUTH0_CLIENT_SECRET}\","

declare data=$(cat <<EOL
{
    "grant_type" : "http://auth0.com/oauth/grant-type/passwordless/otp",
    "client_id": "${AUTH0_CLIENT_ID}", ${secret}
    "realm": "${AUTH0_CONNECTION}",
    "username": "${username}",
    "otp": "${otp_code}",
    "scope": "${AUTH0_SCOPE}",
    "device": "bash"
}
EOL
)

curl --url "https://${AUTH0_DOMAIN}/oauth/token" \
    --header 'content-type: application/json' \
    --data "${data}"
