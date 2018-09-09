#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

declare users_file=''
declare connection_id=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-c connection_id] [-f users.file] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -c id       # connection_id
        -f file     # users file 
        -h|?        # usage
        -v          # verbose

eg,
     $0 -f users.json -c con_Z1QogOOq4sGa1iR9
END
    exit $1
}

while getopts "e:a:f:c:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        c) connection_id=${OPTARG};;
        f) users_file=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${connection_id}" ]] && { echo >&2 "ERROR: connection_id undefined."; usage 1; }
[[ -z "${users_file}" ]] && { echo >&2 "ERROR: users_file undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

curl -v -H "Authorization: Bearer ${access_token}" \
    -F users=@${users_file} \
    -F connection_id=${connection_id} \
    -F upsert=false \
    -F send_completion_email=false \
    --url ${AUTH0_DOMAIN_URL}api/v2/jobs/users-imports 

