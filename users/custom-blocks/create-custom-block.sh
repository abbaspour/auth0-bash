#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-A access_token] [-i user_id] [-r reason_code] [-v|-h]
        -e file      # .env file location (default cwd)
        -i action   # user_id
        -r reason   # reason_code
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'auth0|123' -r soft_delete
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

declare reason_code=''
declare user_id=''

while getopts "e:a:i:r:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) user_id=$(urlencode ${OPTARG}) ;;
    r) reason_code=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z ${user_id} ]] && { echo >&2 "ERROR: no 'user_id' defined"
    exit 1
}
[[ -z ${reason_code} ]] && { echo >&2 "ERROR: no 'reason_code' defined"
    exit 1
}

[[ -z ${access_token} ]] && { echo >&2 -e "ERROR: no 'access_token' defined. \n open -a safari https://manage.auth0.com/#/apis/ \n export access_token=\`pbpaste\`"
    exit 1
}

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:user_custom_blocks"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare -r created_at=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

declare BODY=$( cat <<EOL
{
  "reason_code": "${reason_code}"
}
EOL
)

curl -s -H "Authorization: Bearer ${access_token}" -H 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/users/${user_id}/custom-blocks" \
    --data "${BODY}"
