#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -ueo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-l enrollment-ticket] [-i device-identifier] [-n device-name] [-g gcm-token] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -l ticket      # enrollment-ticket
        -i identifier  # device-identifier
        -n device-name # device-name (defaults to "auth0-bash")
        -g token       # GCM token
        -a token       # APNS token
        -f public.pem  # client public key pem file
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t abbaspour -l ISDspISwKFdc66RCiixgeqG3576XXXX -i f4wjsPTaC4Q:xxxx -n TPB4.xxx.xxx  -f ../ca/mydomain.local.key
END
  exit $1
}

declare AUTH0_DOMAIN=''
declare enrollment_ticket=''
declare device_identifier=''
declare device_name='auth0-bash'
declare token=''
declare public_pem=''
declare service=''

[[ -f "${DIR}/.env" ]] && . "${DIR}/.env"


while getopts "e:t:d:l:i:n:g:a:f:hv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  t) AUTH0_DOMAIN=$(echo ${OPTARG}.guardian.auth0.com | tr '@' '.') ;;
  d) AUTH0_DOMAIN=${OPTARG} ;;
  l) enrollment_ticket=${OPTARG} ;;
  i) device_identifier=${OPTARG} ;;
  n) device_name=${OPTARG} ;;
  g) service="GCM"; token=${OPTARG} ;;
  a) service="APNS"; token=${OPTARG} ;;
  f) public_pem=${OPTARG} ;;
  v) set -x ;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${enrollment_ticket}" ]] && { echo >&2 "ERROR: enrollment_ticket undefined"; usage 1; }
[[ -z "${device_identifier}" ]] && { echo >&2 "ERROR: device_identifier undefined"; usage 1; }
[[ -z "${device_name}" ]] && { echo >&2 "ERROR: device_name undefined"; usage 1; }
[[ -f "${public_pem}" ]] || { echo >&2 "ERROR: public_pem missing: ${public_pem}"; usage 1; }

declare -r BODY=$(cat <<EOL
{
    "identifier":"${device_identifier}",
    "name": "${device_name}",
    "push_credentials": {
      "service": "${service}",
      "token": "${token}"
    },
    "public_key": $(./create-jwk.sh -f "${public_pem}")
}
EOL
)

#echo $BODY | jq .

[[ ${AUTH0_DOMAIN} =~ ^http ]] || AUTH0_DOMAIN=https://${AUTH0_DOMAIN}

curl -s -H "Authorization: Ticket id=\"${enrollment_ticket}\"" \
    -H "Auth0-Client: eyJuYW1lIjoiR3VhcmRpYW4uc3dpZnQiLCJ2ZXJzaW9uIjoiMS4xLjAifQ" \
    --url "${AUTH0_DOMAIN}/api/enroll" \
    -H 'content-type: application/json' \
    --data "${BODY}"
