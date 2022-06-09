##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -euo pipefail

which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }
which jq > /dev/null || { echo >&2 "error: jq not found"; exit 3; }declare -r DIR=$(dirname "${BASH_SOURCE[0]}")



function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # connection id
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i c_123
END
    exit $1
}

declare connection_id=''

while getopts "e:a:i:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) connection_id=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {
    echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
    usage 1
}
[[ -z "${connection_id}" ]] && {
    echo >&2 "ERROR: connection_id undefined."
    usage 1
}

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

curl --request DELETE \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id}"
