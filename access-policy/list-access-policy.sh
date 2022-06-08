##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which awk >/dev/null || {
    echo >&2 "error: awk not found"
    exit 3
}

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-i id] [-v|-h]
        -e file         # .env file location (default cwd)
        -A token        # access_token. default from environment variable
        -i policy_id    # access policy id
        -a audience     # resource server API audience
        -s scopes       # scopes to grant
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i id
END
    exit $1
}

declare uri=''

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:A:i:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    A) access_token=${OPTARG} ;;
    i) uri="/${OPTARG}" ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {
    echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
    usage 1
}
declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

curl -k -s --request GET \
    -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/access-policies${uri} | jq .
