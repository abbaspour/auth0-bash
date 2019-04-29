#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which awk > /dev/null || { echo >&2 "error: awk not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-m email] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -m email        # admin email 
        -h|?            # usage
        -v              # verbose

eg,
     $0 -m me@example.com
END
    exit $1
}

declare admin_email=''

while getopts "e:a:m:t:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        m) admin_email=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${admin_email}" ]] && { echo >&2 "ERROR: admin_email undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

declare BODY=$(cat <<EOL
{
  "owners": ["${admin_email}"]
}
EOL
)

curl -k --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/tenants/invitations

exit 0


