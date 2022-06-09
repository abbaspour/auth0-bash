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

declare user_id=''
declare mfa_provider=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-p provider] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i user_id  # user_id, e.g. 'auth0|5b5fb9702e0e740478884234'
        -p provider # MFA provider other than guardian. e.g. google-authenticator, duo
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'auth0|5b5fb9702e0e740478884234' -p google-authenticator
END
    exit $1
}

while getopts "e:a:i:p:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) user_id=${OPTARG} ;;
    p) mfa_provider=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {
    echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
    usage 1
}
[[ -z "${user_id}" ]] && {
    echo >&2 "ERROR: user_id undefined."
    usage 1
}
[[ -z "${mfa_provider}" ]] && {
    echo >&2 "ERROR: mfa_provider undefined."
    usage 1
}

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

curl -v -H "Authorization: Bearer ${access_token}" \
    --request DELETE \
    --url "${AUTH0_DOMAIN_URL}api/v2/users/${user_id}/multifactor/${mfa_provider}"
