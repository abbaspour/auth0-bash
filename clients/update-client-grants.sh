##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -euo pipefail

which curl > /dev/null || { echo >&2 "error: curl not found"; exit 3; }
which jq > /dev/null || { echo >&2 "error: jq not found"; exit 3; }

declare -r DIR=$(dirname ${BASH_SOURCE[0]})



<<<<<<< HEAD
which awk >/dev/null || {
    echo >&2 "error: awk not found"
    exit 3
}
=======

>>>>>>> 4f4050b (fix: add extra check for curl and jq availabilty)

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-A access_token] [-i grant_id] [-s scopes] [-m|-v|-h]
        -e file         # .env file location (default cwd)
        -A token        # access_token. default from environment variable
        -i id           # grant_id
        -s scopes       # scopes to grant
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i cgr_hoNhUx20xV7p6zqE -s read:client_grants,create:client_grants
END
    exit $1
}

declare grant_id=''
declare api_scopes=''

while getopts "e:A:i:s:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    A) access_token=${OPTARG} ;;
    i) grant_id=${OPTARG} ;;
    s) api_scopes=${OPTARG} ;;
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
[[ -z "${grant_id}" ]] && {
    echo >&2 "ERROR: grant_id undefined."
    usage 1
}

for s in $(echo $api_scopes | tr ',' ' '); do
    scopes+="\"${s}\","
done
scopes=${scopes%?}

declare BODY=$(
    cat <<EOL
{
  "scope": [ ${scopes} ]
}
EOL
)

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/client-grants/${grant_id}

echo
