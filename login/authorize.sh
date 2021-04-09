#!/bin/bash

set -eo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

##
# prerequisite:
# 1. create a clients with type SPA
# 2. add allowed callback to clients: https://jwt.io
# 3. ./authorize.sh -t tenant -c client_id
##

declare AUTH0_REDIRECT_URI='https://jwt.io'
declare AUTH0_SCOPE='openid profile email'
declare AUTH0_RESPONSE_TYPE='token id_token'
declare AUTH0_RESPONSE_MODE=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-a audience] [-r connection] [-R response_type] [-f flow] [-u callback] [-s scope] [-p prompt] [-M mode] [-m|-C|-o|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -a audience    # Audience
        -r realm       # Connection
        -R types       # comma separated response types (default is "${AUTH0_RESPONSE_TYPE}")
        -f flow        # OAuth2 flow type (implicit,code,pkce,hybrid)
        -u callback    # callback URL (default ${AUTH0_REDIRECT_URI})
        -s scopes      # comma separated list of scopes (default is "${AUTH0_SCOPE}")
        -p prompt      # prompt type: none, silent, login, consent
        -M model       # response_mode of: web_message, form_post, fragment
        -S state       # state
        -n nonce       # nonce
        -H hint        # login hint
        -O org_id      # organisation id
        -C             # copy to clipboard
        -P             # pretty print
        -m             # Management API audience
        -o             # Open URL
        -b browser     # Choose browser to open (firefox, chrome, safari)
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
            *) printf '%s' "$c" | xxd -p -u -c1 |
                   while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}

random32() {
    for i in {0..32}; do echo -n $(( RANDOM % 10 )); done
}

base64URLEncode() {
    echo -n "$1" | base64 -w0 |  tr '+' '-' | tr '/' '_' | tr -d '='
}

gen_code_verifier() {
    local rand=$(random32)
    echo $(base64URLEncode ${rand})
}

gen_code_challenge() {
    local cc=$(echo -n "$1" | openssl dgst -binary -sha256)
    echo $(base64URLEncode "$cc")
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CONNECTION=''
declare AUTH0_AUDIENCE=''
declare AUTH0_PROMPT=''

declare opt_open=''
declare opt_clipboard=''
declare opt_flow='implicit'
declare opt_mgmnt=''
declare opt_state=''
declare opt_nonce='mynonce'
declare opt_login_hint=''
declare opt_org_id=''
declare opt_verbose=0
declare opt_browser=''
declare opt_pp=0

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:d:c:a:r:R:f:u:p:s:b:M:S:n:H:O:mCoPhv?" opt
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
        M) AUTH0_RESPONSE_MODE=${OPTARG};;
        s) AUTH0_SCOPE=`echo ${OPTARG} | tr ',' ' '`;;
        S) opt_state=${OPTARG};;
        n) opt_nonce=${OPTARG};;
        H) opt_login_hint=${OPTARG};;
        O) org_id=${OPTARG};;
        C) opt_clipboard=1;;
        P) opt_pp=1;;
        o) opt_open=1;;
        m) opt_mgmnt=1;;
        b) opt_browser="-a ${OPTARG} ";;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"; usage 1; }

[[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/"

declare response_param=''

case ${opt_flow} in
    implicit) response_param="response_type=`urlencode "${AUTH0_RESPONSE_TYPE}"`";;
    *code) response_param='response_type=code';;
    pkce|hybrid) code_verifier=$(gen_code_verifier); code_challenge=$(gen_code_challenge "${code_verifier}"); echo "code_verifier=${code_verifier}"; response_param="code_challenge_method=S256&code_challenge=${code_challenge}"
        if  [[ ${opt_flow} == 'pkce' ]]; then response_param+='&response_type=code'; else response_param+='&response_type=code%20token%20id_token'; fi;;
    *) echo >&2 "ERROR: unknown flow: ${opt_flow}"; usage 1;;
esac

[[ ${AUTH0_DOMAIN} =~ ^http ]] || AUTH0_DOMAIN=https://${AUTH0_DOMAIN}

declare authorize_url="${AUTH0_DOMAIN}/authorize?client_id=${AUTH0_CLIENT_ID}&${response_param}&nonce=`urlencode ${opt_nonce}`&redirect_uri=`urlencode ${AUTH0_REDIRECT_URI}`&scope=`urlencode "${AUTH0_SCOPE}"`"

[[ -n "${AUTH0_AUDIENCE}" ]] && authorize_url+="&audience=$(urlencode "${AUTH0_AUDIENCE}")"
[[ -n "${AUTH0_CONNECTION}" ]] &&  authorize_url+="&connection=${AUTH0_CONNECTION}"
[[ -n "${AUTH0_PROMPT}" ]] &&  authorize_url+="&prompt=${AUTH0_PROMPT}"
[[ -n "${AUTH0_RESPONSE_MODE}" ]] &&  authorize_url+="&response_mode=${AUTH0_RESPONSE_MODE}"
[[ -n "${opt_state}" ]] &&  authorize_url+="&state=$(urlencode "${opt_state}")"
[[ -n "${opt_login_hint}" ]] &&  authorize_url+="&login_hint=$(urlencode "${opt_login_hint}")"
[[ -n "${org_id}" ]] &&  authorize_url+="&organization=$(urlencode "${org_id}")"

if [[ -z ${opt_pp} ]]; then
  echo "${authorize_url}"
else
  echo "${authorize_url}" | sed -E 's/&/ &\
      /g'
fi

[[ -n "${opt_clipboard}" ]] && echo "${authorize_url}" | pbcopy
[[ -n "${opt_open}" ]] && open ${opt_browser} "${authorize_url}"

