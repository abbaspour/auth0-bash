#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -ueo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-s scopes] [-a audience] [-m|-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -s scopes      # scope1,scope2,etc
        -a audience    # API audience
        -m             # Management API audience
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -c aIioQEeY7nJdX78vcQWDBcAqTABgKnZl
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CLIENT_SECRET=''
declare AUTH0_AUDIENCE=''

declare opt_verbose=0
declare opt_mgmnt=''

declare audience_field=''
declare scopes_field=''

while getopts "e:t:d:c:a:s:mhv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    s)
        scopes=$(echo ${OPTARG} | tr , ' ')
        scopes_field=",\"scope\":\"${scopes}\""
        ;;
    a) audience_field=",\"audience\":\"${OPTARG}\"" ;;
    m) opt_mgmnt=1 ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined";  usage 1; }


[[ -n "${opt_mgmnt}" ]] && audience_field=",\"audience\":\"https://${AUTH0_DOMAIN}/api/v2/\""

declare BODY=$(
    cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}"
    ${audience_field}
    ${scopes_field}
}
EOL
)

curl -ss --header 'content-type: application/json' -d "${BODY}" https://${AUTH0_DOMAIN}/oauth/device/code | jq .

echo -e "\n Polling:\n ./exchange.sh -d ${AUTH0_DOMAIN} -c ${AUTH0_CLIENT_ID} -D DEVICE_CODE"
