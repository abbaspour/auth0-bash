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
USAGE: $0 [-e env] [-t tenant] [-d domain] [-s state] [-x secret] [-o|-h]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -s state       # state
        -x secret      # global client secret
        -a token       # Token
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au -s XXXXX -x YYYYYY
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare state=''
declare secret=''

declare opt_verbose=0

while getopts "e:t:d:s:x:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    t) AUTH0_DOMAIN=$(echo ${OPTARG}.auth0.com | tr '@' '.') ;;
    d) AUTH0_DOMAIN=${OPTARG} ;;
    s) state=${OPTARG} ;;
    x) secret=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && {  echo >&2 "ERROR: AUTH0_DOMAIN undefined";  usage 1;  }
[[ -z "${state}" ]] && { echo >&2 "ERROR: state undefined";  usage 1; }

[[ -z "${secret}" ]] && { echo >&2 "ERROR: secret undefined";  usage 1; }


declare -r axs_hash=$(echo -n ${state} | openssl dgst -sha256 -hmac ${secret} -binary | openssl base64)
declare -r axs=$(printf "axs.alpha.%s.%s" ${state} ${axs_hash})

curl -s -X POST \
    -H "Authorization: Bearer $axs" \
    --url https://${AUTH0_DOMAIN}/state/introspect | jq .
