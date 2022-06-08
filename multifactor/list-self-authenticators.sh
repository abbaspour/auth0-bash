##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'auth0|5b5fb9702e0e740478884234'
END
    exit $1
}

while getopts "e:a:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {
    echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
    usage 1
}

#declare -r AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')
declare -r AUTH0_DOMAIN_URL='https://abbaspour.auth0.com/'

curl -s -H "Authorization: Bearer ${access_token}" \
    --request GET \
    --url "${AUTH0_DOMAIN_URL}mfa/authenticators"
