##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

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

declare factor=''
declare value=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-f flag:true|false] [-s true|false] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -f factor   # factor e.g. push-notification
        -s value    # enabled value, true or false
        -h|?        # usage
        -v          # verbose

eg,
     $0 -f push-notification -s true
END
    exit $1
}

while getopts "e:a:f:s:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    f) factor=${OPTARG} ;;
    s) value=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {
    echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
    usage 1
}
[[ -z "${factor}" ]] && {
    echo >&2 "ERROR: factor undefined."
    usage 1
}
[[ -z "${value}" ]] && {
    echo >&2 "ERROR: value undefined."
    usage 1
}

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare BODY=$(
    cat <<EOL
{
  "enabled": ${value}
}
EOL
)

curl -v -H "Authorization: Bearer ${access_token}" \
    --request PUT \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/guardian/factors/${factor}
