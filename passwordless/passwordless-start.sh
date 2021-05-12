#!/bin/bash

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare AUTH0_SCOPE='openid email'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-r connection] [-R code|link] [-u email] [-p phone_number] [-s scope] [-m|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -a audience    # Audience
        -r realm       # Connection (email or sms)
        -R types       # code or link (default is code)
        -s scopes      # comma separated list of scopes (default is "${AUTH0_SCOPE}")
        -p number      # SMS phone number
        -u email       # Email address
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

declare email=''
declare phone_number=''
declare send='code'

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:d:c:a:r:R:u:p:s:mCPohv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.');;
        d) AUTH0_DOMAIN=${OPTARG};;
        c) AUTH0_CLIENT_ID=${OPTARG};;
        a) AUTH0_AUDIENCE=${OPTARG};;
        r) AUTH0_CONNECTION=${OPTARG};;
        R) send=${OPTARG};;
        u) email=${OPTARG};;
        p) phone_number=${OPTARG};;
        s) AUTH0_SCOPE=$(echo "${OPTARG}" | tr ',' ' ');;
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
[[ -z "${AUTH0_CONNECTION}" ]] && { echo >&2 "ERROR: AUTH0_CONNECTION undefined. select 'sms' or 'email'"; usage 1; }

declare recipient=''

case "${AUTH0_CONNECTION}" in
    sms) [[ -z "${phone_number}" ]] && { echo >&2 "ERROR: phone_number undefined"; usage 1; }; recipient="\"phone_number\":\"${phone_number}\",";;
    email) [[ -z "${email}" ]] && { echo >&2 "ERROR: email undefined"; usage 1; }; recipient="\"email\":\"${email}\",";;
    *)  echo >&2 "ERROR: unknown connection: ${AUTH0_CONNECTION}"; usage 1;;
esac

[[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/"         # audience is unsupported in OTP (23/08/18)

readonly data=$(cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}", 
    "connection":"${AUTH0_CONNECTION}", 
    ${recipient}
    "send":"${send}",
    "authParams":{"scope": "${AUTH0_SCOPE}","state": "SOME_STATE", "response_type" : "code", "audience":"${AUTH0_AUDIENCE}"}
}
EOL
)

curl --request POST \
  --url "https://${AUTH0_DOMAIN}/passwordless/start" \
  --header 'content-type: application/json' \
  --data "${data}"

