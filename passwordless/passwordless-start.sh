##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare AUTH0_SCOPE='openid email'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-x secret] [-r email|sms] [-R code|link] [-u email] [-p phone_number] [-s scope] [-l lang] [-m|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -x secret      # Auth0 client secret (optional)
        -a audience    # Audience
        -r realm       # Connection (email or sms)
        -R types       # code or link (default is code)
        -s scopes      # comma separated list of scopes (default is "${AUTH0_SCOPE}")
        -p number      # SMS phone number
        -u email       # Email address
        -U redirect    # redirect_uri
        -l language    # preferred language. default is ${language}
        -m             # Management API audience
        -P             # Preview mode
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -u user@email.com
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CONNECTION=''
declare redirect_uri='https://jwt.io'

declare email=''
declare phone_number=''
declare send='code'
declare language='en'

[[ -f ${DIR}/.env ]] && . "${DIR}/.env"

while getopts "e:t:d:c:x:a:r:R:u:p:s:U:l:mCPohv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    x) AUTH0_CLIENT_SECRET=${OPTARG} ;;
    a) AUTH0_AUDIENCE=${OPTARG} ;;
    r) AUTH0_CONNECTION=${OPTARG} ;;
    R) send=${OPTARG} ;;
    u) email=${OPTARG} ;;
    p) phone_number=${OPTARG} ;;
    l) language=${OPTARG} ;;
    s) AUTH0_SCOPE=$(echo "${OPTARG}" | tr ',' ' ') ;;
    U) redirect_uri=${OPTARG} ;;
    C) opt_clipboard=1 ;;
    o) opt_open=1 ;;
    P) opt_preview=1 ;;
    m) opt_mgmnt=1 ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {
    echo >&2 "ERROR: AUTH0_DOMAIN undefined"
    usage 1
}
[[ -z "${AUTH0_CLIENT_ID}" ]] && {
    echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"
    usage 1
}
[[ -z "${AUTH0_CONNECTION}" ]] && {
    echo >&2 "ERROR: AUTH0_CONNECTION undefined. select 'sms' or 'email'"
    usage 1
}

declare recipient=''

case "${AUTH0_CONNECTION}" in
sms)
    [[ -z "${phone_number}" ]] && {
        echo >&2 "ERROR: phone_number undefined"
        usage 1
    }
    recipient="\"phone_number\":\"${phone_number}\","
    ;;
email)
    [[ -z "${email}" ]] && {
        echo >&2 "ERROR: email undefined"
        usage 1
    }
    recipient="\"email\":\"${email}\","
    ;;
*)
    echo >&2 "ERROR: unknown connection: ${AUTH0_CONNECTION}"
    usage 1
    ;;
esac

[[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/" # audience is unsupported in OTP (23/08/18)

declare secret=''
[[ -n "${AUTH0_CLIENT_SECRET}" ]] && secret="\"client_secret\":\"${AUTH0_CLIENT_SECRET}\","

readonly data=$(
    cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}", ${secret}
    "connection":"${AUTH0_CONNECTION}",
    ${recipient}
    "send":"${send}",
    "authParams":{"scope": "${AUTH0_SCOPE}","state": "SOME_STATE", "response_type" : "id_token", "nonce": "my-nonce", "audience":"${AUTH0_AUDIENCE}", "redirect_uri": "${redirect_uri}", "user_metadata": {"key":"value"}}
}
EOL
)
# -H 'auth0-forwarded-for: 1.2.3.4' \
curl --request POST \
    --url "https://${AUTH0_DOMAIN}/passwordless/start" \
    --header 'content-type: application/json' \
    --header "x-request-language: ${language}" \
    --data "${data}"
