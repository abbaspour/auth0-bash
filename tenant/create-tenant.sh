#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which awk > /dev/null || { echo >&2 "error: awk not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-n name] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -n name         # tenant name (e.g. "tenant01")
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n "my-tenant" 
END
    exit $1
}

declare tenant_name=''

while getopts "e:a:n:t:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        n) tenant_name=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${tenant_name}" ]] && { echo >&2 "ERROR: tenant_name undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

declare BODY=$(cat <<EOL
{
  "name": "${tenant_name}"
}
EOL
)

curl -k --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/tenants

exit 0


