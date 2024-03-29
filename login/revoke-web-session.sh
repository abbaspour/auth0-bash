#!/usr/bin/env bash

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i user_id  # user_id
        -s val      # profile field value to set
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i 'auth0|b0dec5bdba02248abd51388'
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

while getopts "e:a:i:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) user_id=$(urlencode ${OPTARG}) ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${user_id}" ]] && { echo >&2 "ERROR: no 'user_id' defined";  usage 1; }


[[ -z "${access_token}" ]] && { echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`";  usage 1; }


declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare -r email=$(curl -s --get -H "Authorization: Bearer ${access_token}" -H 'content-type: application/json' \
    "${AUTH0_DOMAIN_URL}api/v2/users/${user_id}" | jq -r .email)

echo "Email: ${email}"

declare DATA=$(cat <<EOF
{
    "email":"${email}"
}
EOF
)

curl -X PATCH \
    -H "Authorization: Bearer ${access_token}" \
    -H 'content-type: application/json' \
    -d "${DATA}" \
    "${AUTH0_DOMAIN_URL}api/v2/users/${user_id}"
