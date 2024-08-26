#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-i client_id] [-x client_secret] [-a audience] [-m|-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain or edge location
        -c client_id   # Auth0 client ID
        -x secret      # Auth0 client secret
        -a audience    # API audience
        -k kid         # client public key jwt id
        -f private.pem # client private key pem file
        -m             # Management API audience
        -n api_key     # cname_api_key
        -C cert.pem    # client certificate for mTLS
        -S             # mark request as CA signed
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -i aIioQEeY7nJdX78vcQWDBcAqTABgKnZl -x XXXXXX -m
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
declare cname_api_key=''
declare client_certificate=''
declare ca_signed='FAILED: self signed certificate'
declare opt_mgmnt=''

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"

while getopts "e:t:d:c:a:x:k:f:n:C:Smhv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
  d) AUTH0_DOMAIN=${OPTARG} ;;
  c) AUTH0_CLIENT_ID=${OPTARG} ;;
  x) AUTH0_CLIENT_SECRET=${OPTARG} ;;
  a) AUTH0_AUDIENCE=${OPTARG} ;;
  k) kid=${OPTARG} ;;
  f) private_pem=${OPTARG} ;;
  n) cname_api_key=${OPTARG} ;;
  C) client_certificate=$(jq -sRr @uri "${OPTARG}") ;;
  S) ca_signed='SUCCESS' ;;
  m) opt_mgmnt=1 ;;
  v) set -x ;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"; usage 1; }

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

readonly BODY=$(cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}", ${secret}
    "audience":"${AUTH0_AUDIENCE}",
    "grant_type":"client_credentials"
    ${client_assertion}
}
EOL
)

if [[ -z "${cname_api_key}"  ]]; then
  curl -s -k --header 'content-type: application/json' -d "${BODY}" "https://${AUTH0_DOMAIN}/oauth/token"
else
  curl -s -k --header 'content-type: application/json' -d "${BODY}" \
    --header "cname-api-key: ${cname_api_key}" \
    --header "client-certificate: ${client_certificate}" \
    --header "client-certificate-ca-verified: ${ca_signed}" \
    "https://${AUTH0_DOMAIN}/oauth/token"
fi
