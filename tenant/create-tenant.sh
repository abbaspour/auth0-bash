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
USAGE: $0 [-e env] [-a access_token] [-n name] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -n name         # tenant name (e.g. "tenant01")
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n "my-tenant" 
END
    exit $1
}

declare tenant_name=''

while getopts "e:a:n:t:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    n) tenant_name=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:tenants"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${tenant_name}" ]] && { echo >&2 "ERROR: tenant_name undefined.";  usage 1; }


declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare BODY=$(
    cat <<EOL
{
  "name": "${tenant_name}"
}
EOL
)

curl -k --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url ${AUTH0_DOMAIN_URL}api/v2/tenants

exit 0
