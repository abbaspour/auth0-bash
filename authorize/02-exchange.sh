#!/bin/bash

set -ueo pipefail 

declare -r DIR=$(dirname ${BASH_SOURCE[0]})
. ${DIR}/.env


function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-x client_secret] [-u callback] [-a authorization_code] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -x secret      # Auth0 client secret
        -a code        # Code to exchange
        -u callback    # callback URL
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -c aIioQEeY7nJdX78vcQWDBcAqTABgKnZl -x XXXXXX -a 803131zx232
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CLIENT_SECRET=''
declare AUTH0_REDIRECT_URI=''
declare opt_verbose=0
declare authorization_code=''

while getopts "e:t:d:c:a:x:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        c) AUTH0_CLIENT_ID=${OPTARG};;
        x) AUTH0_CLIENT_SECRET=${OPTARG};;
        u) AUTH0_REDIRECT_URI=${OPTARG};;
        a) authorization_code=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_SECRET}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_SECRET undefined"; usage 1; }
[[ -z "${AUTH0_REDIRECT_URI}" ]] && { echo >&2 "ERROR: AUTH0_REDIRECT_URI undefined"; usage 1; }
[[ -z "${authorization_code}" ]] && { echo >&2 "ERROR: authorization_code undefined"; usage 1; }

declare BODY=$(cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}",
    "client_secret":"${AUTH0_CLIENT_SECRET}",
    "code": "${authorization_code}",
    "grant_type":"authorization_code",
    "redirect_uri": "${AUTH0_REDIRECT_URI}"
}
EOL
)

curl --request POST \
  --url https://${AUTH0_DOMAIN}/oauth/token \
  --header 'content-type: application/json' \
  --data "${BODY}"

