#!/bin/bash

set -euo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-p primary] [-s secondary] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # Access Token
        -p user_id     # primary user_id
        -s user_id     # secondary user_id
        -h|?           # usage
        -v             # verbose

eg,
     $0 -p 'auth0|5b15eef91c08db5762548fd1' -s 'google-oauth2|103723346187275709910'
END
    exit $1
}

declare secondary_userId=''
declare primary_userId=''
declare opt_verbose=0

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:a:p:s:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        p) primary_userId=${OPTARG};;
        s) secondary_userId=`echo ${OPTARG} | tr '|' '/'`;;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined"; usage 1; }
[[ -z "${primary_userId}" ]] && { echo >&2 "ERROR: primary_userId undefined"; usage 1; }
[[ -z "${secondary_userId}" ]] && { echo >&2 "ERROR: secondary_userId undefined"; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

curl -X DELETE  -H "Authorization: Bearer $access_token" ${AUTH0_DOMAIN_URL}api/v2/users/${primary_userId}/identities/${secondary_userId}
