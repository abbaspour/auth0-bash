#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-06-27
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
function usage() {
    cat <<END >&2
USAGE: $0 [-e file] [-t tenant] [-d domain]
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

while getopts "e:t:d:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }

curl -s "https://${AUTH0_DOMAIN}/.well-known/assetlinks.json" | jq '.'
