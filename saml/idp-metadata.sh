#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Application ID with SAML Addon Enabled (i.e. IdP)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -c 62qDW3H3goXmyJTvpzQzMFGLpVGAJ1Qh
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''

declare opt_verbose=0

while getopts "e:t:d:c:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    u) user_id=${OPTARG} ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined.";  usage 1; }

[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined.";  usage 1; }


curl -s --request GET \
    -o idp-${AUTH0_DOMAIN}-${AUTH0_CLIENT_ID}-metadata.xml \
    --url "https://${AUTH0_DOMAIN}/samlp/metadata/${AUTH0_CLIENT_ID}"
