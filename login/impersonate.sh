##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -ueo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})
[[ -f ${DIR}/.env ]] && . ${DIR}/.env

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-i user_id] [-i user_id] [-p protoclo] [-c client_id] [-a audience] [-R response_type] [-v|-h]
        -e file           # .env file location (default cwd)
        -t tenant         # Auth0 tenant@region
        -d domain         # Auth0 domain
        -i user_id        # target user_id
        -u impersonator   # impersonator user_id
        -c client_id      # Auth0 client ID
        -h|?              # usage
        -v                # verbose

eg,
     $0 -t amin01@au -c aIioQEeY7nJdX78vcQWDBcAqTABgKnZl -i 'auth0|user' -u 'auth0|manager' 
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_CLIENT_ID=''

declare opt_verbose=0

declare user_id=''
declare impersonator_id=''
declare protocol='oauth2'

while getopts "e:t:d:c:i:u:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    c) AUTH0_CLIENT_ID=${OPTARG} ;;
    i) user_id=${OPTARG} ;;
    u) impersonator_id=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
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
[[ -z "${user_id}" ]] && {
    echo >&2 "ERROR: user_id undefined"
    usage 1
}
[[ -z "${impersonator_id}" ]] && {
    echo >&2 "ERROR: impersonator_id undefined"
    usage 1
}

declare BODY=$(
    cat <<EOL
{
  protocol: "${protocol}",
  impersonator_id: "${impersonator_id}",
  client_id: "${client_id}",
  additionalParameters: [
    "response_type": "code",
    "state": "STATE"
  ]
}
EOL
)

curl -s --header 'content-type: application/json' \
    --header "Authorization: Bearer ${access_token}" \
    -d "${BODY}" https://${AUTH0_DOMAIN}/users/{user_id}/impersonate
