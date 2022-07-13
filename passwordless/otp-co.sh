#!/usr/bin/env bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare AUTH0_CLIENT='{"name":"auth0.js","version":"9.0.2"}'
declare AUTH0_CLIENT_B64=$(echo -n ${AUTH0_CLIENT} | base64)

urlencode() {
    local length="${#1}"
    for ((i = 0; i < length; i++)); do
        local c="${1:i:1}"
        case ${c} in
        [a-zA-Z0-9.~_-]) printf "$c" ;;
        *) printf '%s' "$c" | xxd -p -c1 |
            while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}

declare AUTH0_CONNECTION='email'
declare ORIGIN='https://jwt.io'
declare AUTH0_SCOPE='openid email'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-u username] [-p pass] [-r connection] [-s scope] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -u username    # Username (phone_number or email)
        -p password    # Password (OTP code received over SMS or Emailed)
        -r realm       # Connection (sms or email, default ${AUTH0_CONNECTION})
        -s scope       # scope (default ${AUTH0_SCOPE})
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -u +61450445200 -p XXXXXX -c 1iSgx01LN27oEgpFfGvG2UASbpSndtXg -m
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_AUDIENCE=''
declare USERNAME=''
declare PASSWORD=''
declare opt_mgmnt=''
declare opt_verbose=0

while getopts "e:t:d:c:a:u:p:r:o:u:s:mhv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    a) AUTH0_AUDIENCE=${OPTARG} ;;
    u) USERNAME=${OPTARG} ;;
    p) PASSWORD=${OPTARG} ;;
    r) AUTH0_CONNECTION=${OPTARG} ;;
    u) AUTH0_REDIRECT_URI=${OPTARG} ;;
    s) AUTH0_SCOPE=$(echo ${OPTARG} | tr ',' ' ') ;;
    m) opt_mgmnt=1 ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined";  usage 1; }

[[ -z "${AUTH0_CONNECTION}" ]] && { echo >&2 "ERROR: AUTH0_CONNECTION undefined. select 'sms' or 'email'";  usage 1; }


[[ -z "${USERNAME}" ]] && { echo >&2 "ERROR: USERNAME undefined.";  usage 1; }

[[ -z "${PASSWORD}" ]] && { echo >&2 "ERROR: PASSWORD undefined.";  usage 1; }


declare BODY=$(cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}",
    "username":"${USERNAME}",
    "otp":"${PASSWORD}",
    "realm":"${AUTH0_CONNECTION}",
    "credential_type":"http://auth0.com/oauth/grant-type/passwordless/otp"
}
EOL
)

echo "CO Body: ${BODY}"

declare co_response=$(curl -s -c cookie.txt -H "Content-Type: application/json" \
    -H "origin: ${ORIGIN}" \
    -H "auth0-clients: ${AUTH0_CLIENT_B64}" \
    -d "${BODY}" https://${AUTH0_DOMAIN}/co/authenticate)

echo "CO Response: ${co_response}"

declare login_ticket=$(echo ${co_response} | jq -cr .login_ticket)
echo "login_ticket=${login_ticket}"

declare authorize_url="https://${AUTH0_DOMAIN}/authorize?client_id=${AUTH0_CLIENT_ID}&response_type=$(urlencode "token id_token")&redirect_uri=$(urlencode ${ORIGIN})&scope=$(urlencode "${AUTH0_SCOPE}")&login_ticket=${login_ticket}&state=mystate&nonce=mynonce&auth0Client=${AUTH0_CLIENT_B64}&audience=$(urlencode ${AUTH0_AUDIENCE})"

echo "authorize_url: ${authorize_url}"

declare location=$(curl -s -I -b cookie.txt ${authorize_url} | awk '/^location: /{print $2}')

echo "Redirect location: ${location}"

declare access_token=$(echo ${location} | grep -oE "access_token=([^&]+)" | awk -F= '{print $2}')
declare id_token=$(echo ${location} | grep -oE "id_token=([^&]+)" | awk -F= '{print $2}')

declare access_token_json=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null)
declare id_token_json=$(echo ${id_token} | awk -F. '{print $2}' | base64 -di)

echo "Access Token: ${access_token_json}"
echo "ID     Token: ${id_token_json}"
