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
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-u email] [-r connection] [-p password] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -u email       # Users email address
        -p password    # (optional) new password
        -r connection  # Connection name
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -c aIioQEeY7nJdX78vcQWDBcAqTABgKnZl -u some@body.com
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CONNECTION='Username-Password-Authentication'
declare opt_verbose=0
declare email=''
declare password=''

while getopts "e:t:d:c:u:p:r:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    u) email=${OPTARG} ;;
    p) password=${OPTARG} ;;
    r) AUTH0_CONNECTION=${OPTARG} ;;
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
[[ -z "${email}" ]] && {
    echo >&2 "ERROR: email undefined"
    usage 1
}

declare BODY=$(
    cat <<EOL
{
    "client_id": "${AUTH0_CLIENT_ID}",
    "email": "${email}",
    "password": "${password}",
    "connection": "${AUTH0_CONNECTION}"
}
EOL
)

curl --request POST \
    --url https://${AUTH0_DOMAIN}/dbconnections/change_password \
    --header 'content-type: application/json' \
    --data "${BODY}"
