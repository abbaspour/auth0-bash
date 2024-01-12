#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-t tenant] [-d domain] [-a audience] [-s scopes] [-S state] [-C cookie] [-n|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -a audience    # audience
        -s scopes      # scopes to consent to
        -S state       # state
        -C cookie      # auth0 cookie from /authorize page
        -n             # no consent, i.e. decline
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -a my.cool.api -s do:work -S XXXXX -C XXX
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare AUTH0_AUDIENCE=''
declare AUTH0_SCOPE=''
declare state=''
declare decision=''
declare cookie=''

declare opt_verbose=0

while getopts "e:t:d:a:s:S:C:n:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    a) AUTH0_AUDIENCE=${OPTARG} ;;
    s) AUTH0_SCOPE=$(echo ${OPTARG} | tr ',' ' ') ;;
    S) state=${OPTARG} ;;
    C) cookie=${OPTARG} ;;
    n) decision='decline' ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }
[[ -z "${AUTH0_AUDIENCE}" ]] && { echo >&2 "ERROR: AUTH0_AUDIENCE undefined";  usage 1; }

[[ -z "${state}" ]] && { echo >&2 "ERROR: state undefined";  usage 1; }

[[ -z "${cookie}" ]] && { echo >&2 "ERROR: cookie undefined";  usage 1; }


declare scopes_str=''
for s in ${AUTH0_SCOPE}; do
    scopes_str+="-d scope[]=${s} "
done

curl -v -X POST \
    --cookie "auth0=${cookie}" \
    -d audience=${AUTH0_AUDIENCE} \
    -d state=${state} \
    -d cancel=${decision} \
    $(echo ${scopes_str}) \
    --url https://${AUTH0_DOMAIN}/decision
