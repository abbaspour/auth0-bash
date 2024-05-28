#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-05-20
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au
END
    exit $1
}

declare AUTH0_DOMAIN=''

declare opt_verbose=0

while getopts "e:t:d:c:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined.";  usage 1; }

echo "Downloading to: sp-${AUTH0_DOMAIN}-cert.pem"

curl -s --request GET \
    -o sp-${AUTH0_DOMAIN}-cert.pem \
    --url "https://${AUTH0_DOMAIN}/pem?cert=connection"

cat "sp-${AUTH0_DOMAIN}-cert.pem"