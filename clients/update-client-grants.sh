#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which awk > /dev/null || { echo >&2 "error: awk not found"; exit 3; }

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

while getopts "e:A:i:s:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        A) access_token=${OPTARG};;
        i) grant_id=${OPTARG};;
        s) api_scopes=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')
[[ -z "${grant_id}" ]] && { echo >&2 "ERROR: grant_id undefined."; usage 1; }


for s in `echo $api_scopes | tr ',' ' '`; do
    scopes+="\"${s}\","
done
scopes=${scopes%?}

declare BODY=$(cat <<EOL
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

