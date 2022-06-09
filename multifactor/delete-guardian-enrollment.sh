#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -euo pipefail

which curl >/dev/null || {
    echo >&2 "error: curl not found"
    exit 3
}
which jq >/dev/null || {
    echo >&2 "error: jq not found"
    exit 3
}

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

declare enrollment_id=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i enrollment_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # Guardian enrollment id 
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'push|dev_NBFIwJ1df2rM6loH'
END
    exit $1
}

while getopts "e:a:i:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) enrollment_id=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {
    echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
    usage 1
}
[[ -z "${enrollment_id}" ]] && {
    echo >&2 "ERROR: enrollment_id undefined."
    usage 1
}

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

curl -s -H "Authorization: Bearer ${access_token}" \
    --request DELETE \
    --url "${AUTH0_DOMAIN_URL}api/v2/guardian/enrollments/${enrollment_id}"
