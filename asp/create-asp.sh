#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

which awk > /dev/null || { echo >&2 "error: awk not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-A access_token] [-i user_id] [-a audience] [-n label] [-s scopes] [-v|-h]
        -e file         # .env file location (default cwd)
        -A token        # access_token. default from environment variable
        -i id           # user id
        -a audience     # resource server API audience
        -s scopes       # scopes to grant
        -n label        # ASP label
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i 'auth0|5b5fb9702e0e740478884234' -a my.api -s read:data,write:data -n "My ASP"
END
    exit $1
}

declare user_id=''
declare audience=''
declare api_scopes=''
declare asp_name=''

while getopts "e:A:i:a:s:n:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        A) access_token=${OPTARG};;
        i) user_id=${OPTARG};;
        a) audience=${OPTARG};;
        s) api_scopes=${OPTARG};;
        n) asp_name=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${user_id}" ]] && { echo >&2 "ERROR: user_id undefined."; usage 1; }
[[ -z "${audience}" ]] && { echo >&2 "ERROR: audience undefined."; usage 1; }
[[ -z "${asp_name}" ]] && { echo >&2 "ERROR: asp_name undefined."; usage 1; }


declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

declare scopes=''
for s in `echo $api_scopes | tr ',' ' '`; do
    scopes+="\"${s}\","
done
scopes=${scopes%?}

declare BODY=$(cat <<EOL
{
  "label" : "${asp_name}",
  "audience": "${audience}",
  "scope": [ ${scopes} ]
}
EOL
)

curl --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/users/${user_id}/application-passwords

