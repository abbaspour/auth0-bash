#!/usr/bin/env bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i grant_id] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # Access Token
        -i id          # grant id
        -u user_id     # user_id
        -h|?           # usage
        -v             # verbose

eg,
     $0 -i 5bcd5f14a2cc5cb9c16fe980
     $0 -u 'windowslive|63dd7bfd36exxxx'
END
    exit $1
}

declare grantId=''
declare user_id=''
declare opt_verbose=0

while getopts "e:a:i:u:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) grantId=${OPTARG} ;;
    u) user_id=${OPTARG} ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="delete:grants"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

#[[ -z "${grantId}" ]] && { echo >&2 "ERROR: grant_id undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

if [[ -n "${grantId}" ]]; then
    curl -s --request DELETE \
        -H "Authorization: Bearer ${access_token}" \
        --url "${AUTH0_DOMAIN_URL}api/v2/grants/${grantId}"
elif [[ -n "${user_id}" ]]; then
    curl -s --request DELETE \
        -H "Authorization: Bearer ${access_token}" \
        --url "${AUTH0_DOMAIN_URL}api/v2/grants?user_id=${user_id}"
else echo >&2 "ERROR: grant_id or user_id required."
    usage 1
fi
