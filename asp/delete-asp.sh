#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

which curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
which jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

declare user_id=''
declare asp_id=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -u user_id  # user_id
        -i provider # ASP id
        -h|?        # usage
        -v          # verbose

eg,
     $0 -u 'auth0|5b5fb9702e0e740478884234' -i asp_ynCXW4CeSG65UnSC
END
    exit $1
}

while getopts "e:a:i:u:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    u) user_id=${OPTARG} ;;
    i) asp_id=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="delete:user_application_passwords"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${user_id}" ]] && {  echo >&2 "ERROR: user_id undefined.";  usage 1; }

[[ -z "${asp_id}" ]] && { echo >&2 "ERROR: asp_id undefined.";  usage 1; }


declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

curl -H "Authorization: Bearer ${access_token}" \
    --request DELETE \
    --url "${AUTH0_DOMAIN_URL}api/v2/users/${user_id}/application-passwords/${asp_id}"
