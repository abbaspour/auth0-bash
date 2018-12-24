#!/bin/bash

set -eo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-a access_token] [-m|-C|-o|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -a token       # Access Token
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -a J7REwk4c6tJo29jmMV0AZZ79vBd8_qTz
END
    exit $1
}


declare AUTH0_DOMAIN=''
declare access_token=''

declare opt_verbose=0

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:t:d:a::hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        a) access_token=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined"; usage 1; }

curl -s -H "Authorization: Bearer ${access_token}" https://${AUTH0_DOMAIN}/oauth/token | jq '.'
