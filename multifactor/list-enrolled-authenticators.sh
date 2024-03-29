#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-m mfa_token]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -m token       # MFA token
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -m "\${mfa_token}"
END
    exit $1
}

declare AUTH0_DOMAIN=''

declare opt_verbose=0

while getopts "e:t:d:m:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    m) mfa_token=${OPTARG} ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }
[[ -z "${mfa_token}" ]] && { echo >&2 "ERROR: mfa_token undefined";  usage 1; }


curl -s --request GET \
    --url "https://${AUTH0_DOMAIN}/mfa/authenticators" \
    --header "authorization: Bearer ${mfa_token}" \
    --header 'content-type: application/x-www-form-urlencoded' | jq .
