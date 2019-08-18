#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which awk > /dev/null || { echo >&2 "error: awk not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-A access_token] [-r resource_server] [-a audience] [-s scopes] [-m|-v|-h]
        -e file         # .env file location (default cwd)
        -A token        # access_token. default from environment variable
        -r rs           # resource_server identifier
        -a audience     # resource server API audience
        -s scopes       # scopes to grant
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i some_api -a other_api -s list:things,update:things
END
    exit $1
}

declare resource_server=''
declare audience=''
declare api_scopes=''

while getopts "e:A:r:a:s:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        A) access_token=${OPTARG};;
        r) resource_server=${OPTARG};;
        a) audience=${OPTARG};;
        s) api_scopes=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')
[[ -z "${resource_server}" ]] && { echo >&2 "ERROR: resource_server undefined."; usage 1; }
[[ -z "${audience}" ]] && { echo >&2 "ERROR: audience undefined."; usage 1; }
[[ -z "${api_scopes}" ]] && { echo >&2 "ERROR: api_scopes undefined."; usage 1; }


for s in `echo ${api_scopes} | tr ',' ' '`; do
    scopes+="\"${s}\","
done
scopes=${scopes%?}

declare BODY=$(cat <<EOL
{
  "resource_server_identifier": "${resource_server}",
  "audience": "${audience}",
  "scope": [ ${scopes} ]
}
EOL
)

curl -k --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/api-grants

