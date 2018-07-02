#!/bin/bash

set -euo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})
. ${DIR}/.env

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

[ -f cookie.txt ] || { echo "no cookie.txt found. run 02-authenticate.sh first."; exit ; }

declare CONNECTION='Username-Password-Authentication'
declare ORIGIN='http://app1.com:3000'

declare AUTH0_CLIENT='{"name":"auth0.js","version":"9.0.2"}'
declare AUTH0_CLIENT_B64=$(echo -n $AUTH0_CLIENT | base64)

declare check_session_url="https://${AUTH0_DOMAIN}/authorize?client_id=${AUTH0_CLIENT_ID}&response_type=`urlencode "id_token token"`&redirect_uri=`urlencode ${ORIGIN}`&scope=`urlencode "openid profile email"`&audience=${AUTH0_AUDIANCE}&connection=${CONNECTION}&state=mystate&nonce=mynonce&auth0Client=${AUTH0_CLIENT_B64}&response_mode=web_message&prompt=none"

curl -b cookie.txt $check_session_url 

