#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################


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
USAGE: $0 [-e env] [-a access_token] [-i client_id] [-m k1:v1,k2:v2] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # grant_id
        -m key:value    # metadata key:value
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i 62qDW3H3goXmyJTvpzQzMFGLpVGAJ1Qh -m first_party:true,region:AU
END
    exit $1
}

declare client_id=''
declare metadata=''

while getopts "e:a:i:m:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) client_id=${OPTARG} ;;
    m) metadata=${OPTARG} ;;
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
[[ -z "${client_id}" ]] && {
    echo >&2 "ERROR: client_id undefined."
    usage 1
}
[[ -z "${metadata}" ]] && {
    echo >&2 "ERROR: metadata undefined."
    usage 1
}

scopes=''
for s in $(echo $metadata | tr ',' ' '); do
    scopes+=$(echo $s | awk -F: '{printf("\"%s\":\"%s\",", \$1, \$2)}')
done
scopes=${scopes%?}

declare BODY=$(
    cat <<EOL
{
  "client_metadata": { ${scopes} }
}
EOL
)

curl -s --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/clients/${client_id}

echo
