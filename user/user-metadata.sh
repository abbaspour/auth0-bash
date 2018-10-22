#!/bin/bash

set -euo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})
[[ -f ${DIR}/.env ]] && . ${DIR}/.env

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-u user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -u user_id  # user_id
        -h|?        # usage
        -v          # verbose

eg,
     $0 -u 'auth0|b0dec5bdba02248abd51388'
END
    exit $1
}

declare user_id=''

while getopts "e:a:u:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        u) user_id=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${user_id}" ]] && { echo >&2 "ERROR: user_id undefined"; usage 1; }

[[ -z ${access_token+x} ]] && { echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"; exit 1; }
declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')


declare DATA=$(cat <<EOF
{
    "user_metadata":{ "plan": "gold" }
}
EOF
)

curl --request PATCH \
  --header "Authorization: Bearer ${access_token}" \
  --url ${AUTH0_DOMAIN_URL}api/v2/users/${user_id} \ # urlencode
  --header 'content-type: application/json' \
  --data "${DATA}"


