#!/bin/bash

set -euo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})
. ${DIR}/.env

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-a access_token] [-p primary] [-s secondary] [-v|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -a token       # Access Token
        -p user_id     # primary user_id
        -s user_id     # secondary user_id
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -p 'auth0|5b15eef91c08db5762548fd1' -s 'google-oauth2|103723346187275709910'
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare access_token=''
declare secondary_userId=''
declare primary_userId=''
declare opt_verbose=0

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:d:a:p:s:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        a) access_token=${OPTARG};;
        p) primary_userId=${OPTARG};;
        s) secondary_userId=`echo ${OPTARG} | tr '|' '/'`;;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined"; usage 1; }
[[ -z "${primary_userId}" ]] && { echo >&2 "ERROR: primary_userId undefined"; usage 1; }
[[ -z "${secondary_userId}" ]] && { echo >&2 "ERROR: secondary_userId undefined"; usage 1; }

curl -X DELETE  -H "Authorization: Bearer $access_token" https://${AUTH0_DOMAIN}/api/v2/users/${primary_userId}/identities/${secondary_userId}
