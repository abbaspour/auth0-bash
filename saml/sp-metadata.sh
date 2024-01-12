#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c connection] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c connection  # Enterprise SAMLP connection name
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -c 62qDW3H3goXmyJTvpzQzMFGLpVGAJ1Qh
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CONNECTION=''

declare opt_verbose=0

while getopts "e:t:d:c:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CONNECTION=${OPTARG} ;;
    u) user_id=${OPTARG} ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined.";  usage 1; }

[[ -z "${AUTH0_CONNECTION}" ]] && { echo >&2 "ERROR: AUTH0_CONNECTION undefined.";  usage 1; }


curl -s --request GET \
    -o sp-${AUTH0_DOMAIN}-${AUTH0_CONNECTION}-metadata.xml \
    --url "https://${AUTH0_DOMAIN}/samlp/metadata?connection=${AUTH0_CONNECTION}"
