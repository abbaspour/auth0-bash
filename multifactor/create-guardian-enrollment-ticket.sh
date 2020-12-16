#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})


function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i user_id  # user_id
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'auth0|xxxxx'
END
    exit $1
}

declare user_id=''

while getopts "e:a:i:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        i) user_id=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${user_id}" ]] && { echo >&2 "ERROR: user_id undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

declare BODY=$(cat <<EOL
{
    "user_id": "${user_id}",
    "send_mail": false
}
EOL
)

curl -s -H "Authorization: Bearer ${access_token}" \
    --header 'content-type: application/json' -d "${BODY}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/guardian/enrollments/ticket"
