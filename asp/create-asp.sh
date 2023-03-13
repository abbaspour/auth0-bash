#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-A access_token] [-i user_id] [-a audience] [-n label] [-s scopes] [-v|-h]
        -e file         # .env file location (default cwd)
        -A token        # access_token. default from environment variable
        -i id           # user id
        -a audience     # resource server API audience
        -s scopes       # scopes to grant
        -n label        # ASP label
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i 'auth0|5b5fb9702e0e740478884234' -a my.api -s read:data,write:data -n "My ASP"
END
    exit $1
}

declare user_id=''
declare audience=''
declare api_scopes=''
declare asp_name=''

while getopts "e:A:i:a:s:n:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    A) access_token=${OPTARG} ;;
    i) user_id=${OPTARG} ;;
    a) audience=${OPTARG} ;;
    s) api_scopes=${OPTARG} ;;
    n) asp_name=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }

[[ -z "${user_id}" ]] && {  echo >&2 "ERROR: user_id undefined.";  usage 1; }

[[ -z "${audience}" ]] && { echo >&2 "ERROR: audience undefined."; usage 1; }
[[ -z "${asp_name}" ]] && { echo >&2 "ERROR: asp_name undefined."; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:user_application_passwords"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare scopes=''
for s in $(echo $api_scopes | tr ',' ' '); do
    scopes+="\"${s}\","
done
scopes=${scopes%?}

declare BODY=$( cat <<EOL
{
  "label" : "${asp_name}",
  "audience": "${audience}",
  "scope": [ ${scopes} ]
}
EOL
)

curl --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/users/${user_id}/application-passwords
