#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare TWILIO_SID=''
declare TWILIO_AUTH_TOKEN=''
declare TWILIO_FROM=''
declare TWILIO_TO=''
declare MESSAGE=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e file] [-f from] [-t to] [-m message] [-s SID] [-x AuthToken] [-v|-h]
        -e file        # .env file location (default cwd)
        -f number      # from Number
        -t to          # to Number
        -m "message"   # SMS message text
        -s SID         # Twilio Account SID
        -x AuthToken   # Twilio Auth Token
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t "+61450000270" -m "hi from Auth0"
END
    exit $1
}

declare opt_verbose=0

while getopts "e:f:t:m:s:x:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    f) TWILIO_FROM=${OPTARG} ;;
    t) TWILIO_TO=${OPTARG} ;;
    m) MESSAGE=${OPTARG} ;;
    s) TWILIO_SID=${OPTARG} ;;
    x) TWILIO_AUTH_TOKEN=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${TWILIO_SID}" ]] && { echo >&2 "ERROR: TWILIO_SID undefined";  usage 1; }

[[ -z "${TWILIO_AUTH_TOKEN}" ]] && { echo >&2 "ERROR: TWILIO_AUTH_TOKEN undefined";  usage 1; }

[[ -z "${TWILIO_FROM}" ]] && { echo >&2 "ERROR: TWILIO_FROM undefined";  usage 1; }

[[ -z "${TWILIO_TO}" ]] && { echo >&2 "ERROR: TWILIO_TO undefined";  usage 1; }

[[ -z "${MESSAGE}" ]] && { echo >&2 "ERROR: MESSAGE undefined";  usage 1; }


curl -X POST https://api.twilio.com/2010-04-01/Accounts/${TWILIO_SID}/Messages.json \
    --data-urlencode "Body=${MESSAGE}" \
    --data-urlencode "From=${TWILIO_FROM}" \
    --data-urlencode "To=${TWILIO_TO}" \
    -u ${TWILIO_SID}:${TWILIO_AUTH_TOKEN}
