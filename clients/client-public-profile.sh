#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################


set -eo pipefail

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-n name] [-t type] [-i client_id] [-p PEM] [-c callbacks] [-v|-h]
        -e file         # .env file location (default cwd)
        -t tenant       # auth0 tenant
        -d domain       # auth0 domain
        -i client_id    # client_id (if accept_client_id_on_creation is on)
        -h|?            # usage
        -v              # verbose

eg,
     $0 -d tenant -i client_123
END
  exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''

while getopts "e:t:d:i:hv?" opt; do
  case ${opt} in
  e) source ${OPTARG} ;;
  t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
  d) AUTH0_DOMAIN=${OPTARG} ;;
  i) AUTH0_CLIENT_ID=${OPTARG} ;;
  v) set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined";  usage 1; }

curl -s "https://${AUTH0_DOMAIN}/client/${AUTH0_CLIENT_ID}.js"  | sed -n 's/Auth0\.setClient(\(.*\));/\1/p' | jq .
