#!/usr/bin/env bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-p primary] [-s secondary] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # Access Token
        -i user_id     # primary user_id
        -p provider    # second user's provider
        -s user_id     # secondary user_id
        -h|?           # usage
        -v             # verbose

eg,
     $0 -i 'auth0|5b15eef91c08db5762548fd1' -p 'google-oauth2' -s '103723346187275709910'
END
    exit $1
}

declare secondary_userId=''
declare userId=''
declare provider=''
declare opt_verbose=0

while getopts "e:a:i:p:s:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) userId=${OPTARG} ;;
    p) provider=${OPTARG} ;;
    s) secondary_userId=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:users"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${userId}" ]] && { echo >&2 "ERROR: userId undefined";  usage 1; }

[[ -z "${secondary_userId}" ]] && { echo >&2 "ERROR: secondary_userId undefined";  usage 1; }

[[ -z "${provider}" ]] && { echo >&2 "ERROR: provider undefined";  usage 1; }


declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

curl -X DELETE -H "Authorization: Bearer $access_token" \
    --url "${AUTH0_DOMAIN_URL}api/v2/users/${userId}/identities/${provider}/${secondary_userId}"
