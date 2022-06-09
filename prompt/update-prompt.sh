#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -euo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-p prompt] [-l language] [-s screen] [-i text-id] [-t text]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -p prompt   # prompt name
        -l lang     # language (default en)
        -s screen   # screen name
        -i id       # text_id
        -t text     # text
        -h|?        # usage
        -v          # verbose

eg,
     $0 -p mfa-push -s mfa-push-welcome -i pageTitle -t "New Title"
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

[[ -z "${access_token}" ]] && {
    echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
    usage 1
}

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:prompts"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${prompt}" ]] && {
    echo >&2 "ERROR: prompt undefined."
    usage 1
}
[[ -z "${screen}" ]] && {
    echo >&2 "ERROR: screen undefined."
    usage 1
}
[[ -z "${text_id}" ]] && {
    echo >&2 "ERROR: text_id undefined."
    usage 1
}
[[ -z "${text}" ]] && {
    echo >&2 "ERROR: text undefined."
    usage 1
}

readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

readonly BODY=$(
    cat <<EOL
{
  "${screen}": {
    "${text_id}": "${text}"
  }
}
EOL
)

curl --request PUT \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/prompts/${prompt}/custom-text/${lang}"
