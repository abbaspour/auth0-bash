#!/bin/bash

set -euo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

urlencode() {
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%s' "$c" | xxd -p -c1 |
                   while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}


declare AUTH0_REDIRECT_URI='https://jwt.io'                     # add this to "Allowed Callback URLs" of your application
declare AUTH0_ORIGIN='https://jwt.io'                           # add this to "Allowed Web Origins" of your application
declare AUTH0_CONNECTION='Username-Password-Authentication'
declare AUTH0_SCOPE='openid profile email'

declare -r AUTH0_CLIENT='{"name":"auth0.js","version":"9.0.2"}'
declare -r AUTH0_CLIENT_B64=$(echo -n $AUTH0_CLIENT | base64)

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-u username] [-p pass] [-r connection] [-o origin] [-U callback] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -u username    # Username
        -p password    # Password
        -r realm       # Connection (default ${AUTH0_CONNECTION})
        -o origin      # Allowed Origin (default ${AUTH0_ORIGIN})
        -U callback    # callback URL (default ${AUTH0_REDIRECT_URI})
        -a audience    # audience
        -s scopes      # scopes (comma-separated, default "${AUTH0_SCOPE}")
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -u somebody@gmail.com  -p XXXXX -c 1iSgx01LN27oEgpFfGvG2UASbpSndtXg -m
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

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:d:c:a:u:p:r:o:U:s:mhv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        c) AUTH0_CLIENT_ID=${OPTARG};;
        a) AUTH0_AUDIENCE=${OPTARG};;
        u) USERNAME=${OPTARG};;
        p) PASSWORD=${OPTARG};;
        r) AUTH0_CONNECTION=${OPTARG};;
        o) AUTH0_ORIGIN=${OPTARG};;
        U) AUTH0_REDIRECT_URI=${OPTARG};;
        s) AUTH0_SCOPE=`echo ${OPTARG} | tr ',' ' '`;;
        m) opt_mgmnt=1;;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"; usage 1; }
[[ -z "${USERNAME}" ]] && { echo >&2 "ERROR: USERNAME undefined"; usage 1; }
[[ -z "${PASSWORD}" ]] && { echo >&2 "ERROR: PASSWORD undefined"; usage 1; }

[[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/"

declare BODY=$(cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}",
    "username":"${USERNAME}",
    "password":"${PASSWORD}",
    "realm":"${AUTH0_CONNECTION}",
    "credential_type":"http://auth0.com/oauth/grant-type/password-realm"
}
EOL
)

declare co_response=$(curl -s -c cookie.txt -H "Content-Type: application/json" \
    -H "origin: ${AUTH0_ORIGIN}" \
    -H "auth0-clients: ${AUTH0_CLIENT_B64}" \
    -d "${BODY}" https://${AUTH0_DOMAIN}/co/authenticate)

echo "CO Response: ${co_response}"

## TODO: check `jq` installed
declare login_ticket=$(echo $co_response | jq -cr .login_ticket)
echo login_ticket=${login_ticket}

declare authorize_url="https://${AUTH0_DOMAIN}/authorize?client_id=${AUTH0_CLIENT_ID}&response_type=`urlencode "id_token token"`&redirect_uri=`urlencode ${AUTH0_REDIRECT_URI}`&scope=`urlencode ${AUTH0_SCOPE}`&login_ticket=${login_ticket}&state=mystate&nonce=mynonce&auth0Client=${AUTH0_CLIENT_B64}"

[[ -n "${AUTH0_AUDIENCE}" ]] && authorize_url+="&audience=`urlencode ${AUTH0_AUDIENCE}`"
[[ -n "${AUTH0_CONNECTION}" ]] &&  authorize_url+="&realm=${AUTH0_CONNECTION}"

echo "authorize_url: ${authorize_url}"

declare location=$(curl -s -I -b cookie.txt $authorize_url | awk 'IGNORECASE = 1;/^location: /{print $2}')

echo "Redirect location: ${location}"

[[ ${location} =~ ^/mf ]] && { echo >&2 "WARNING: MFA enabled. CO not possible without user interaction"; exit 3; }
[[ ${location} =~ ^/decision ]] && { echo >&2 "WARNING: Consent required. CO not possible without user interaction. Try normal ./authorize.sh first."; exit 3; }

declare access_token=$(echo ${location} | grep -oE "access_token=([^&]+)" | awk -F= '{print $2}')
declare id_token=$(echo ${location} | grep -oE "id_token=([^&]+)" | awk -F= '{print $2}')

## TODO: check if `base64` installed

declare access_token_json=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null)
declare id_token_json=$(echo ${id_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null)

echo "Access Token: ${access_token_json}"
echo "ID     Token: ${id_token_json}"

