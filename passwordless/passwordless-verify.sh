##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

## note:
# this script is using legacy endpoint `/passwordless/verify`.

set -euo pipefail

which curl >/dev/null || {
    echo >&2 "error: curl not found"
    exit 3
}
which jq >/dev/null || {
    echo >&2 "error: jq not found"
    exit 3
}
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

declare AUTH0_SCOPE='openid'

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
        -o otp         # OTP code
        -m             # Management API audience
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -u user@email.com -o 1234
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CONNECTION=''

declare email=''
declare phone_number=''
declare verification_code=''
declare send='code'

while getopts "e:t:d:c:a:r:R:u:p:s:o:mhv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    a) AUTH0_AUDIENCE=${OPTARG} ;;
    r) AUTH0_CONNECTION=${OPTARG} ;;
    R) send=${OPTARG} ;;
    u) email=${OPTARG} ;;
    p) phone_number=${OPTARG} ;;
    s) AUTH0_SCOPE=$(echo ${OPTARG} | tr ',' ' ') ;;
    o) verification_code=${OPTARG} ;;
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
[[ -z "${verification_code}" ]] && {
    echo >&2 "ERROR: OTP verification_code undefined."
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

declare data=$(
    cat <<EOL
{
    "connection": "${AUTH0_CONNECTION}",
    ${recipient}
    "verification_code": "${verification_code}",
    "scope": "${AUTH0_SCOPE}"
}
EOL
)

curl --request POST \
    --url "https://${AUTH0_DOMAIN}/passwordless/verify" \
    --header 'content-type: application/json' \
    --data "${data}"
