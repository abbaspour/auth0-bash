#!/bin/bash

# Same origin interactive login in UL classic mode
# NOTE: this is for training/demo purposes. `/usernamepassword/login` is not a CORS endpoint.

set -euo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

function urlencode() {
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

function urldecode() {
  echo -n $1 | perl -pe 's/\+/ /g; s/%([0-9a-f]{2})/chr(hex($1))/eig'
}

function htmldecode() {
  echo -n $1 | sed 's/&#34;/"/g'
}

declare AUTH0_REDIRECT_URI='https://jwt.io'                     # add this to "Allowed Callback URLs" of your application
declare AUTH0_ORIGIN='https://jwt.io'                           # add this to "Allowed Web Origins" of your application
declare AUTH0_CONNECTION='Username-Password-Authentication'
declare AUTH0_SCOPE='openid profile email'

declare -r DEFAULT_NONCE='mynonce'
declare -r AUTH0_CLIENT='{"name":"auth0.js","version":"9.0.2"}'
declare -r AUTH0_CLIENT_B64=$(echo -n $AUTH0_CLIENT | base64)

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-u username] [-x password] [-r connection] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -u username    # Username
        -x password    # Password
        -r realm       # Connection (default ${AUTH0_CONNECTION})
        -o origin      # Allowed Origin (default ${AUTH0_ORIGIN})
        -U callback    # callback URL (default ${AUTH0_REDIRECT_URI})
        -a audience    # audience
        -s scopes      # scopes (comma-separated, default "${AUTH0_SCOPE}")
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -u somebody@gmail.com -x notsosecret -c 1iSgx01LN27oEgpFfGvG2UASbpSndtXg -m
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

while getopts "e:t:d:c:a:u:x:r:o:U:s:mhv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        c) AUTH0_CLIENT_ID=${OPTARG};;
        a) AUTH0_AUDIENCE=${OPTARG};;
        u) USERNAME=${OPTARG};;
        x) PASSWORD=${OPTARG};;
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

declare -r AUTH0_TENANT=$(echo ${AUTH0_DOMAIN} | awk -F[./] '{print $1}')

[[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/"

declare authorize_url="https://${AUTH0_DOMAIN}/authorize?client_id=${AUTH0_CLIENT_ID}&response_type=`urlencode "id_token"`&redirect_uri=`urlencode ${AUTH0_REDIRECT_URI}`&scope=`urlencode ${AUTH0_SCOPE}`&state=mystate&nonce=${DEFAULT_NONCE}" #&auth0Client=${AUTH0_CLIENT_B64}

[[ -n "${AUTH0_AUDIENCE}" ]] && authorize_url+="&audience=`urlencode ${AUTH0_AUDIENCE}`"
[[ -n "${AUTH0_CONNECTION}" ]] &&  authorize_url+="&realm=${AUTH0_CONNECTION}"

echo "authorize_url: ${authorize_url}"

declare login_location=$(curl -s -I -b cookie.txt --url "$authorize_url" | grep -i -E "^location: " | awk '{print $2}' | tr -d '\r')

loign=`urldecode ${login_location}`

declare -r login_page=https://${AUTH0_DOMAIN}${loign}

echo "Redirect to login page: ${login_page}"

declare  -r authParams_b64=$(curl -v -c cookie.txt -b cookie.txt --url "${login_page}" 2>&1 | grep  "window.atob('[^']*" -o | cut -c14-)

declare -r authParams=$(echo ${authParams_b64} | base64 -di 2>/dev/null)

declare -r _csrf=$(echo ${authParams} | jq -cr '._csrf' )
declare -r state=$(echo ${authParams} | jq -cr '.state' )

declare BODY=$(cat <<EOL
{
    "client_id": "${AUTH0_CLIENT_ID}",
    "redirect_uri": "${AUTH0_REDIRECT_URI}",
    "tenant": "${AUTH0_TENANT}",
    "response_type": "id_token",
    "scope": "${AUTH0_SCOPE}",
    "state":"${state}",
    "nonce":"${DEFAULT_NONCE}",
    "connection": "${AUTH0_CONNECTION}",
    "username": "${USERNAME}",
    "password": "${PASSWORD}",
    "popup_options": {},
    "sso": true,
    "protocol": "oauth2",
    "prompt": "login",
    "_csrf": "${_csrf}",
    "_intstate":"deprecated"
}
EOL
)

declare -r form_post_body=$(curl -s -b cookie.txt -c cookie.txt -H 'Content-Type: application/json' -d "${BODY}" https://${AUTH0_DOMAIN}/usernamepassword/login)

declare -r callback_url="https://${AUTH0_DOMAIN}/login/callback"
declare -r wresult=$(echo ${form_post_body} | ack 'name="wresult" value="(?P<wresult>[^"]*)' --output '$1')
declare -r wctx=$(echo ${form_post_body} | ack 'name="wctx" value="(?P<wctx>[^"]*)' --output '$1')

wctx_decoded=$(htmldecode "${wctx}")

#echo "callback_url: ${callback_url}"
#echo "wresult: ${wresult}"
#echo "wctx_decoded: ${wctx_decoded}"

declare -r jwt_io_fragment=$(curl -s -b cookie.txt \
  -d "wa=wsignin1.0&wresult=${wresult}&wctx=${wctx_decoded}" \
  --url ${callback_url} | ack 'Found. Redirecting to (.+)' --output '$1')

echo "jwt_io_fragment: ${jwt_io_fragment}"

declare id_token=$(echo ${jwt_io_fragment} | grep -oE "id_token=([^&]+)" | awk -F= '{print $2}')
declare id_token_json=$(echo ${id_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null)

echo "ID     Token: ${id_token_json}"

