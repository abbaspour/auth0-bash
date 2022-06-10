#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

which curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
which jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-c client_id] [-u callback] [-b browser] [-f|-C|-o|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -u callback    # callback URL (default ${AUTH0_REDIRECT_URI})
        -f             # federated logout
        -C             # copy to clipboard
        -o             # Open URL
        -b browser     # Choose browser to open (firefox, chrome, safari)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -f -o -b firefox
END
    exit $1
}

declare opt_federated=0

while getopts "e:t:d:c:u:b:fCohv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    u) AUTH0_REDIRECT_URI=${OPTARG} ;;
    C) opt_clipboard=1 ;;
    o) opt_open=1 ;;
    f) opt_federated=1 ;;
    b) opt_browser="-a ${OPTARG} " ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z ${AUTH0_DOMAIN+x} ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1; }


declare logout_url="https://${AUTH0_DOMAIN}/v2/logout?"

[[ -n "${opt_federated}" ]] && logout_url+="federated&"
[[ -n "${AUTH0_CLIENT_ID}" ]] && logout_url+="client_id=${AUTH0_CLIENT_ID}&"
[[ -n "${AUTH0_REDIRECT_URI}" ]] && logout_url+="returnTo=$(urlencode ${AUTH0_REDIRECT_URI})&"

echo "${logout_url}"

[[ -n "${opt_clipboard}" ]] && echo "${logout_url}" | pbcopy
[[ -n "${opt_open}" ]] && open ${opt_browser} "${logout_url}"
