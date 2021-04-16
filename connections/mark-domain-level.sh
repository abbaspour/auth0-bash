#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which awk > /dev/null || { echo >&2 "error: awk not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i client_id] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i conn_id      # connection id
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n "My App" -t non_interactive
END
    exit $1
}

declare client_id=''

while getopts "e:a:i:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        i) client_id=${OPTARG};;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${client_id}" ]] && { echo >&2 "ERROR: client_id undefined."; usage 1; }

readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')


readonly BODY=$(cat <<EOL
{
  "is_domain_connection": true
}
EOL
)

curl -k --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections/${client_id}"

