#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-t tenant] [-d domain] [-c client_id] [-r realm] [-e email] [-u username] [-p password] [-h]
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c client_id   # Auth0 client ID
        -r connection  # Connection name
        -e email       # email
        -u username    # username (optional)
        -p password    # password
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -c XXXX -r testdb -e me@there.com -p hardpass
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare CONNECTION='Username-Password-Authentication'
declare AUTH0_CLIENT_ID=''
declare email=''
declare username_field=''
declare password=''

[[ -f "${DIR}/.env" ]] && . "${DIR}"/.env

while getopts "t:d:c:r:e:u:p:hv?" opt
do
    case ${opt} in
        t) AUTH0_DOMAIN=$(echo "${OPTARG}.auth0.com" | tr '@' '.');;
        d) AUTH0_DOMAIN=${OPTARG};;
        c) AUTH0_CLIENT_ID=${OPTARG};;
        r) CONNECTION=${OPTARG};;
        e) email=${OPTARG};;
        u) username_field="\"username\": \"${OPTARG}\",";;
        p) password=${OPTARG};;
        v) set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${AUTH0_CLIENT_ID}" ]] && { echo >&2 "ERROR: AUTH0_CLIENT_ID undefined"; usage 1; }
[[ -z "${CONNECTION}" ]] && { echo >&2 "ERROR: CONNECTION undefined"; usage 1; }
[[ -z "${email}" ]] && { echo >&2 "ERROR: email undefined"; usage 1; }
[[ -z "${password}" ]] && { echo >&2 "ERROR: password undefined"; usage 1; }


declare DATA=$(cat <<EOF
{
    "client_id": "${AUTH0_CLIENT_ID}",
    "email": "${email}",
    "password": "${password}",
    "connection": "${CONNECTION}",
    "given_name": "Diego",
    "family_name": "Koga",
    "name" : "Diego Koga",
      ${username_field}
    "user_metadata":{
      "given_name" : "Charles",
      "family_name" : "Kane"
    }
}
EOF
)

curl -s --request POST \
  --url "https://${AUTH0_DOMAIN}/dbconnections/signup" \
  --header 'content-type: application/json' \
  --data "${DATA}" | jq .
