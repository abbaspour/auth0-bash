##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -euo pipefail

which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }
which jq > /dev/null || { echo >&2 "error: jq not found"; exit 3; }
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

declare AUTH0_SCOPE='openid profile email'
declare AUTH0_CONNECTION='Username-Password-Authentication'

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-u username] [-p passsword] [-x client_secret] [-a audience] [-r connection] [-s scope] [-i IP] [-m|-h|-v]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -x secret      # Auth0 client secret
        -u username    # Username or email
        -p password    # Password
        -a audience    # Audience
        -r realm       # Connection (default is "${AUTH0_CONNECTION}")
        -s scopes      # comma separated list of scopes (default is "${AUTH0_SCOPE}")
        -i IP          # set origin IP header. Default is 'x-forwarded-for'
        -C key         # cname-api-key
        -A             # switch to 'auth0-forwarded-for' for trust IP header
        -m             # Management API audience
        -k kid         # client public key jwt id
        -f private.pem # client private key pem file
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -s offline_access -c XXXX -u user -p pass
END
  exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''
declare AUTH0_CLIENT_SECRET=''
declare AUTH0_AUDIENCE=''

declare username=''
declare password=''
declare cname_api_key=''
declare origin_ip='1.2.3.4'

declare ff_prefix='x'
declare opt_mgmnt=''
declare kid=''
declare private_pem=''

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:u:p:d:c:x:a:r:s:i:C:k:f:Amhv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
  u) username=${OPTARG} ;;
  p) password=${OPTARG} ;;
  d) AUTH0_DOMAIN=${OPTARG} ;;
  c) AUTH0_CLIENT_ID=${OPTARG} ;;
  x) AUTH0_CLIENT_SECRET=${OPTARG} ;;
  a) AUTH0_AUDIENCE=${OPTARG} ;;
  r) AUTH0_CONNECTION=${OPTARG} ;;
  s) AUTH0_SCOPE=$(echo ${OPTARG} | tr ',' ' ') ;;
  i) origin_ip=${OPTARG} ;;
  C) cname_api_key=${OPTARG} ;;
  k) kid=${OPTARG} ;;
  f) private_pem=${OPTARG} ;;
  A) ff_prefix='auth0' ;;
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
[[ -z "${username}" ]] && {
  echo >&2 "ERROR: username undefined"
  usage 1
}

#[[ -z "${AUTH0_AUDIENCE}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/userinfo"
[[ -n "${opt_mgmnt}" ]] && AUTH0_AUDIENCE="https://${AUTH0_DOMAIN}/api/v2/"

declare secret=''
[[ -n "${AUTH0_CLIENT_SECRET}" ]] && secret="\"client_secret\": \"${AUTH0_CLIENT_SECRET}\","

if [[ -n "${kid}" && -n "${private_pem}" && -f "${private_pem}" ]]; then
  readonly assertion=$(../clients/client-assertion.sh -d "${AUTH0_DOMAIN}" -i "${AUTH0_CLIENT_ID}" -k "${kid}" -f "${private_pem}")
  readonly client_assertion=$(
    cat <<EOL
  , "client_assertion" : "${assertion}",
  "client_assertion_type": "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
EOL
  )
  echo "client_assertion: ${client_assertion}"
fi

declare BODY=$(
  cat <<EOL
{
            "grant_type": "http://auth0.com/oauth/grant-type/password-realm",
            "realm" : "${AUTH0_CONNECTION}",
            "client_id": "${AUTH0_CLIENT_ID}", ${secret}
            "scope": "${AUTH0_SCOPE}",
            "audience": "${AUTH0_AUDIENCE}",
            "username": "${username}",
            "password": "${password}"
            ${client_assertion}
}
EOL
)

# --header "$ff_prefix-forwarded-for: ${origin_ip}" \
# --header "true-client-ip: 20.30.40.50" \
# --header "cname-api-key: ${cname_api_key}" \

curl -s -k --header 'content-type: application/json' \
  -d "${BODY}" \
  "https://${AUTH0_DOMAIN}/oauth/token"

echo
