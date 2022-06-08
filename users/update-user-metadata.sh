##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -euo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i user_id  # user_id
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'auth0|b0dec5bdba02248abd51388'
END
    exit $1
}

urlencode() {
    local length="${#1}"
    for ((i = 0; i < length; i++)); do
        local c="${1:i:1}"
        case $c in
        [a-zA-Z0-9.~_-]) printf "$c" ;;
        *) printf '%s' "$c" | xxd -p -c1 |
            while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}

declare user_id=''

while getopts "e:a:i:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) user_id=$(urlencode ${OPTARG}) ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

declare -r SUB_FROM_TOKEN=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.sub')
if [[ -z "${user_id}" ]]; then
    [[ -n ${SUB_FROM_TOKEN} ]] && user_id=${SUB_FROM_TOKEN} || {
        echo >&2 "ERROR: user_id undefined"
        usage 1
    }
fi

[[ -z ${access_token+x} ]] && {
    echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"
    exit 1
}
declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare DATA=$(
    cat <<EOF
{
    "user_metadata":{ "plan": "gold4" }
}
EOF
)

curl -s -X PATCH \
    -H "Authorization: Bearer ${access_token}" \
    -H 'content-type: application/json' \
    -d "${DATA}" \
    ${AUTH0_DOMAIN_URL}api/v2/users/${user_id} | jq .
