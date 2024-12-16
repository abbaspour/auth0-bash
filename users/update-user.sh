#!/usr/bin/env bash

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i user_id  # user_id
        -f key      # profile field name. e.g. name, email, given_name, family_name. full list at: https://auth0.com/docs/users/references/user-profile-structure
        -s val      # profile field value to set
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'auth0|b0dec5bdba02248abd51388' -f name -s "Amin"
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

declare user_id=''
declare filed=''
declare value=''

while getopts "e:a:i:f:s:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) user_id=$(urlencode ${OPTARG}) ;;
    f) filed=${OPTARG} ;;
    s) value=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z ${user_id} ]] && { echo >&2 "ERROR: no 'user_id' defined"; usage 1; }
[[ -z ${filed} ]] && { echo >&2 "ERROR: no 'filed' defined"; usage 1; }
[[ -z ${value} ]] && { echo >&2 "ERROR: no 'value' defined"; usage 1; }

[[ -z ${access_token+x} ]] && { echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"; exit 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:users"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare DATA=$(cat <<EOF
{
    "${filed}": "${value}"
}
EOF
)

curl -s -X PATCH \
    -H "Authorization: Bearer ${access_token}" \
    -H 'content-type: application/json' \
    -d "${DATA}" \
    "${AUTH0_DOMAIN_URL}api/v2/users/${user_id}"
