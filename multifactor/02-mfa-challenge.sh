#!/bin/bash

set -eo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})


declare AUTH0_SCOPE='openid profile email'
declare AUTH0_CONNECTION='Username-Password-Authentication'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-x client_secret] [-m mfa_token] [-a authenticator_type]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -x secret      # Auth0 client secret
        -m token       # MFA token
        -a type        # authenticator type: otp, oob
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -m XXXX -a otp
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CLIENT_SECRET=''
declare authenticator_type=''
declare mfa_token=''

declare opt_verbose=0

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:d:c:x:m:a:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        c) AUTH0_CLIENT_ID=${OPTARG};;
        x) AUTH0_CLIENT_SECRET=${OPTARG};;
        m) mfa_token=${OPTARG};;
        a) authenticator_type=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"; usage 1; }
[[ -z "${mfa_token}" ]] && { echo >&2 "ERROR: mfa_token undefined"; usage 1; }
[[ -z "${authenticator_type}" ]] && { echo >&2 "ERROR: authenticator_type undefined"; usage 1; }


declare secret=''
[[ -n "${AUTH0_CLIENT_SECRET}" ]] && secret="\"client_secret\": \"${AUTH0_CLIENT_SECRET}\","


declare BODY=$(cat <<EOL
{
    "client_id": "${AUTH0_CLIENT_ID}",
    ${secret}
    "challenge_type": "${authenticator_type}",
    "mfa_token": "${mfa_token}"
}
EOL
)

declare response_json=`curl -s --header 'content-type: application/json' -d "${BODY}" https://${AUTH0_DOMAIN}/mfa/challenge`

if [ "${authenticator_type}" == "oob" ]; then
    oob_code=`echo ${response_json} | jq -r '.oob_code'` 
    echo "export oob_code=\"${oob_code}\""
fi

