#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which awk > /dev/null || { echo >&2 "error: awk not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i identifier] [-n name] [-s scope] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i identifer    # API identifier (e.g. my.api)
        -n name         # API name (e.g. "My API")
        -s scopes       # comma separated scopes
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i my.api -n "My API" -s read:data,write:data
END
    exit $1
}

declare api_identifier=''
declare api_name=''
declare api_scopes=''

while getopts "e:a:i:n:s:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        i) api_identifier=${OPTARG};;
        n) api_name=${OPTARG};;
        s) api_scopes=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${api_identifier}" ]] && { echo >&2 "ERROR: api_identifier undefined."; usage 1; }
[[ -z "${api_name}" ]] && { echo >&2 "ERROR: api_name undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

for s in `echo $api_scopes | tr ',' ' '`; do
    scopes+="{\"value\":\"${s}\"},"
done
scopes=${scopes%?}

declare BODY=$(cat <<EOL
{
  "identifier": "${api_identifier}",
  "name": "${api_name}",
  "scopes": [ ${scopes} ]
}
EOL
)

curl --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/resource-servers 

