#!/bin/bash

set -eo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

##
# prerequisite:
# 1. create a client with type SPA
# 2. add allowed callback to client: https://jwt.io 
# 3. ./01-authenticate -t tenant -c client_id
##

declare AUTH0_REDIRECT_URI='https://jwt.io'
declare AUTH0_SCOPE='openid profile email'
declare AUTH0_RESPONSE_TYPE='token id_token'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-a audience] [-r connection] [-R response_type] [-f flow] [-u callback] [-s scope] [-p prompt] [-m|-C|-o|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -a audiance    # Audience
        -r realm       # Connection
        -R types       # comma separated response types (default is "${AUTH0_RESPONSE_TYPE}")
        -f flow        # OAuth2 flow type (implicit,code)
        -u callback    # callback URL (default ${AUTH0_REDIRECT_URI})
        -s scopes      # comma separated list of scopes (default is "${AUTH0_SCOPE}")
        -p prompt      # prompt type: none, silent, login
        -C             # copy to clipboard
        -m             # Management API audience
        -o             # Open URL
        -P             # Preview mode 
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -s offline_access -o
END
    exit $1
}

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

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CONNECTION=''
declare AUTH0_AUDIENCE=''
declare AUTH0_PROMPT=''

declare opt_open=''
declare opt_clipboard=''
declare opt_flow=''
declare opt_mgmnt=''
declare opt_preview=''
declare opt_verbose=0

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:d:c:a:r:R:f:u:p:s:mCPohv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        c) AUTH0_CLIENT_ID=${OPTARG};;
        a) AUTH0_AUDIENCE=${OPTARG};;
        r) AUTH0_CONNECTION=${OPTARG};;
        R) AUTH0_RESPONSE_TYPE=`echo ${OPTARG} | tr ',' ' '`;;
        f) opt_flow=${OPTARG};;
        u) AUTH0_REDIRECT_URI=${OPTARG};;
        p) AUTH0_PROMPT=${OPTARG};;
        s) AUTH0_SCOPE=`echo ${OPTARG} | tr ',' ' '`;;
        C) opt_clipboard=1;;
        o) opt_open=1;; 
        P) opt_preview=1;; 
        m) opt_mgmnt=1;;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"; usage 1; }

if [[ -z "${opt_preview}" ]]; then
    [[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/"

    case ${opt_flow} in
        implicit) AUTH0_RESPONSE_TYPE='token id_token';;
        *code) AUTH0_RESPONSE_TYPE='code'
    esac

    declare authorize_url="https://${AUTH0_DOMAIN}/authorize?client_id=${AUTH0_CLIENT_ID}&response_type=`urlencode "${AUTH0_RESPONSE_TYPE}"`&nonce=mynonce&redirect_uri=`urlencode ${AUTH0_REDIRECT_URI}`&scope=`urlencode "${AUTH0_SCOPE}"`"

    [[ -n "${AUTH0_AUDIENCE}" ]] && authorize_url+="&audience=`urlencode ${AUTH0_AUDIENCE}`"
    [[ -n "${AUTH0_CONNECTION}" ]] &&  authorize_url+="&connection=${AUTH0_CONNECTION}"
    [[ -n "${AUTH0_PROMPT}" ]] &&  authorize_url+="&prompt=${AUTH0_PROMPT}"
else 
   declare authorize_url="https://${AUTH0_DOMAIN}/preview/login?client=${AUTH0_CLIENT_ID}"
fi

echo "${authorize_url}"

[[ -n "${opt_clipboard}" ]] && echo "${authorize_url}" | pbcopy
[[ -n "${opt_open}" ]] && open "${authorize_url}"

