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

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] ] [-i id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # rule_id
        -h|?        # usage
        -v          # verbose

eg,
     $0 -i rul_S03VwumO9S3nnxnD
END
    exit $1
}

declare rule_id=''
declare opt_verbose=''

while getopts "e:a:f:i:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    f) script_file=${OPTARG} ;;
    i) rule_id=${OPTARG} ;;
    v) opt_verbose='-v' ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="delete:rules"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${rule_id}" ]] && { echo >&2 "ERROR: rule_id undefined.";  usage 1; }


declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

curl ${opt_verbose} -X DELETE -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/rules/${rule_id}
