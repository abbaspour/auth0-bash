#!/bin/bash

set -euo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-u user_id] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # Access Token
        -u user_id     # (optional) filter by user_id
        -h|?           # usage
        -v             # verbose

eg,
     $0 -u 'auth0|5b15eef91c08db5762548fd1' 
END
    exit $1
}

declare userId=''
declare opt_verbose=0

while getopts "e:a:u:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        u) userId=${OPTARG};;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

declare qs=''
[[ -n "${userId}" ]] && qs="?user_id=${userId}" #jq_query+=" | select(.user_id | contains(\"${userId}\"))"
declare -r jq_query+=".[] | \"\(.id) \(.user_id) \(.audience) \(.clientID)\" "

curl -s --request GET \
    -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/grants${qs} | jq -rc "${jq_query}"
