#!/bin/bash

set -eo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-a access_token] [-o|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c assertion   # client assertion (from ${DIR}/../client-assertion.sh)
        -a token       # Token
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -a J7REwk4c6tJo29jmMV0AZZ79vBd8_qTz -c 'eyJ0eXAiOiJKV1QiLCJhbGciOiJ...ZD92vVGd-ZNGA'
END
    exit $1
}


declare AUTH0_DOMAIN=''
declare token=''

declare opt_verbose=0

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:d:a:c:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        a) token=${OPTARG};;
        c) client_assertion=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${token}" ]] && { echo >&2 "ERROR: access_token undefined"; usage 1; }

declare BODY=$(cat <<EOL
{
  "client_assertion" : "${client_assertion}",
  "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
  "token": "${token}"
}
EOL
)

curl --request POST \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url https://${AUTH0_DOMAIN}/oauth/introspect
