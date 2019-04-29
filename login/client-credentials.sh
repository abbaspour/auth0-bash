#!/bin/bash

set -ueo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})
[[ -f ${DIR}/.env ]] && . ${DIR}/.env

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-x client_secret] [-a audience] [-m|-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -x secret      # Auth0 client secret
        -a audience    # API audience
        -m             # Management API audience
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -c aIioQEeY7nJdX78vcQWDBcAqTABgKnZl -x XXXXXX -m
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CLIENT_SECRET=''
declare AUTH0_AUDIENCE=''

declare opt_verbose=0
declare opt_mgmnt=''

while getopts "e:t:d:c:a:x:mhv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        c) AUTH0_CLIENT_ID=${OPTARG};;
        x) AUTH0_CLIENT_SECRET=${OPTARG};;
        a) AUTH0_AUDIENCE=${OPTARG};;
        m) opt_mgmnt=1;;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_SECRET}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_SECRET undefined"; usage 1; }

[[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/"

[[ -z "${AUTH0_AUDIENCE}" ]] && { echo >&2 "ERROR: AUTH0_AUDIENCE undefined"; usage 1; }

declare BODY=$(cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}",
    "client_secret":"${AUTH0_CLIENT_SECRET}",
    "audience":"${AUTH0_AUDIENCE}",
    "grant_type":"client_credentials"
}
EOL
)

curl -s -k --header 'content-type: application/json' -d "${BODY}" https://${AUTH0_DOMAIN}/oauth/token

