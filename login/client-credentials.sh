##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -ueo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-x client_secret] [-a audience] [-m|-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -x secret      # Auth0 client secret
        -a audience    # API audience
        -k kid         # client public key jwt id
        -f private.pem # client private key pem file
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
declare secret=''
declare kid=''
declare private_pem=''
declare client_assertion=''
declare opt_mgmnt=''

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:d:c:a:x:k:f:mhv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
  d) AUTH0_DOMAIN=${OPTARG} ;;
  c) AUTH0_CLIENT_ID=${OPTARG} ;;
  x) AUTH0_CLIENT_SECRET=${OPTARG} ;;
  a) AUTH0_AUDIENCE=${OPTARG} ;;
  k) kid=${OPTARG} ;;
  f) private_pem=${OPTARG} ;;
  m) opt_mgmnt=1 ;;
  v) set -x ;;
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

[[ -n "${AUTH0_CLIENT_SECRET}" ]] && secret="\"client_secret\":\"${AUTH0_CLIENT_SECRET}\","
[[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/"

#[[ -z "${AUTH0_AUDIENCE}" ]] && { echo >&2 "ERROR: AUTH0_AUDIENCE undefined"; usage 1; }

if [[ -n "${kid}" && -n "${private_pem}" && -f "${private_pem}" ]]; then
  readonly assertion=$(../clients/client-assertion.sh -d "${AUTH0_DOMAIN}" -i "${AUTH0_CLIENT_ID}" -k "${kid}" -f "${private_pem}")
  client_assertion=$(
    cat <<EOL
  , "client_assertion" : "${assertion}",
  "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
EOL
  )
fi

readonly BODY=$(
  cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}", ${secret}
    "audience":"${AUTH0_AUDIENCE}",
    "grant_type":"client_credentials"
    ${client_assertion}
}
EOL
)

curl -s -k --header 'content-type: application/json' -d "${BODY}" "https://${AUTH0_DOMAIN}/oauth/token"
