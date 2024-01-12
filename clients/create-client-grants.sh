#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-A access_token] [-i client_id] [-a audience] [-s scopes] [-m|-v|-h]
        -e file         # .env file location (default cwd)
        -A token        # access_token. default from environment variable
        -i id           # client id
        -a audience     # resource server API audience
        -s scopes       # scopes to grant
        -m              # Management API audience
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i Q1p8BJPS4yu24GjYaG1YQxxfoAhF4Gbe -m -s read:client_grants,create:client_grants
END
    exit $1
}

declare client_id=''
declare audience=''
declare api_scopes=''
declare use_management_api=0



while getopts "e:A:i:a:s:mhv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    A) access_token=${OPTARG} ;;
    i) client_id=${OPTARG} ;;
    a) audience=${OPTARG} ;;
    s) api_scopes=${OPTARG} ;;
    m) use_management_api=1 ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:client_grants"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

[[ ! -z "${use_management_api}" ]] && audience=${AUTH0_DOMAIN_URL}api/v2/
[[ -z "${client_id}" ]] && {  echo >&2 "ERROR: client_id undefined." ;  usage 1; }


for s in $(echo $api_scopes | tr ',' ' '); do
    scopes+="\"${s}\","
done
scopes=${scopes%?}

declare BODY=$(cat <<EOL
{
  "client_id": "${client_id}",
  "audience": "${audience}",
  "scope": [ ${scopes} ]
}
EOL
)

curl -k --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/client-grants
