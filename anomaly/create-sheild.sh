#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -euo pipefail

which curl >/dev/null || {
    echo >&2 "error: curl not found"
    exit 3
}
which jq >/dev/null || {
    echo >&2 "error: jq not found"
    exit 3
}

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-A access_token] [-a action] [-t trigger] [-i user_id] [-v|-h]
        -e file      # .env file location (default cwd)
        -a action   # action; email_user, email_owner, email_owner_summary_daily, email_owner_summary_weekly, email_owner_summary_monthly, block
        -t trigger  # trigger_id
        -h|?        # usage
        -v          # verbose

eg,
     $0 -a email_user -t
END
    exit $1
}

urlencode() {
    local length="${#1}"
    for ((i = 0; i < length; i++)); do
        local c="${1:i:1}"
        case $c in
        [a-zA-Z0-9.~_-]) printf "$c" ;;
        *) printf '%s' "$c" | xxd -p -c1 |
            while read c; do printf '%%%s' "$c"; done ;;
        esac
    done
}

declare action=''
declare trigger_id=''

while getopts "e:A:a:t:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    A) access_token=${OPTARG} ;;
    a) action=${OPTARG} ;;
    t) trigger_id=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z ${access_token} ]] && {
    echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"
    exit 1
}
declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare BODY=$(
    cat <<EOL
{
  "action": "${action}",
  "trigger": "${trigger_id}"
}
EOL
)

curl -s -H "Authorization: Bearer ${access_token}" -H 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/anomaly/shields" \
    --data "${BODY}"
