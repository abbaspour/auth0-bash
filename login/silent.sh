#!/bin/bash

set -euo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})
[[ -f ${DIR}/.env ]] && . ${DIR}/.env

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

declare AUTH0_REDIRECT_URI='https://jwt.io'
declare AUTH0_ORIGIN='http://app1.myhost.com'
declare AUTH0_CONNECTION='Username-Password-Authentication'
declare AUTH0_SCOPE='openid profile email'
declare COOKIE_FILE='cookie.txt'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-f file] [-c client_id] [-r connection] [-o origin] [-u callback] [-v|-h]
        -e file        # .env file location (default cwd)
        -f file.txt    # Cookie jar file (Netscape format) (default ${COOKIE_FILE})
        -c client_id   # Auth0 client ID
        -u username    # Username
        -p password    # Password
        -r realm       # Connection (default ${AUTH0_CONNECTION})
        -o origin      # Allowed Origin (default ${AUTH0_ORIGIN})
        -u callback    # callback URL (default ${AUTH0_REDIRECT_URI})
        -h|?           # usage
        -v             # verbose

eg,
     $0 -c y4KJ1oOdLyx5lwILRInTbCCx221VCduh -m 
END
    exit $1
}

declare AUTH0_AUDIENCE=''
declare opt_mgmnt=''
declare opt_verbose=0

while getopts "e:f:c:a:r:o:u:s:mhv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        c) AUTH0_CLIENT_ID=${OPTARG};;
        f) COOKIE_FILE=${OPTARG};;
        a) AUTH0_AUDIENCE=${OPTARG};;
        r) AUTH0_CONNECTION=${OPTARG};;
        o) AUTH0_ORIGIN=${OPTARG};;
        u) AUTH0_REDIRECT_URI=${OPTARG};;
        s) AUTH0_SCOPE=`echo ${OPTARG} | tr ',' ' '`;;
        m) opt_mgmnt=1;;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z ${AUTH0_CLIENT_ID+x} ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"; usage 1; }

[ -f ${COOKIE_FILE} ] || { echo "no cookie.txt found. run cross-origin.sh first."; exit ; }

declare AUTH0_DOMAIN=$(grep "^#HttpOnly_" ${COOKIE_FILE} | grep auth0 | awk -F"[\s\t_]" '{print $2}')
[[ -z ${AUTH0_DOMAIN+x} ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }

declare -r AUTH0_CLIENT='{"name":"auth0.js","version":"9.0.2"}'
declare -r AUTH0_CLIENT_B64=$(echo -n $AUTH0_CLIENT | base64)

[[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/"

declare check_session_url="https://${AUTH0_DOMAIN}/authorize?client_id=${AUTH0_CLIENT_ID}&response_type=`urlencode "id_token token"`&redirect_uri=`urlencode ${AUTH0_REDIRECT_URI}`&scope=`urlencode "${AUTH0_SCOPE}"`&state=mystate&nonce=mynonce&auth0Client=${AUTH0_CLIENT_B64}&response_mode=web_message&prompt=none"

[[ -n "${AUTH0_AUDIENCE}" ]] && check_session_url+="&audience=`urlencode ${AUTH0_AUDIENCE}`"
#[[ -n "${AUTH0_CONNECTION}" ]] && check_session_url+="&realm=${AUTH0_CONNECTION}"

curl -b ${COOKIE_FILE} $check_session_url 

