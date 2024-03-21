#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-02-27
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-p prompt]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -p prompt   # prompt name
        -h|?        # usage
        -v          # verbose

eg,
     $0 -p customized-consent
END
    exit ${1}
}

declare prompt=''
declare lang='en'
declare screen=''
declare text_id=''
declare text=''

while getopts "e:a:p:l:s:i:t:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    p) prompt=${OPTARG} ;;
    l) lang=${OPTARG} ;;
    s) screen=${OPTARG} ;;
    i) text_id=${OPTARG} ;;
    t) text=${OPTARG} ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:prompts"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${prompt}" ]] && { echo >&2 "ERROR: prompt undefined.";  usage 1; }

readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

curl --request GET \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/prompts/${prompt}/partials"
