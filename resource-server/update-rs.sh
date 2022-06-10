#!/usr/bin/env bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################


set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # API id
        -f key          # field name. e.g. allow_offline_access, token_dialect, full list at: https://auth0.com/docs/api/management/v2#!/Resource_Servers/patch_resource_servers_by_id
        -s val          # field value to set
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i
END
    exit $1
}

declare api_id=''
declare filed=''
declare value=''

while getopts "e:a:i:f:s:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) api_id=${OPTARG} ;;
    f) filed=${OPTARG} ;;
    s) value=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:resource_servers"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${api_id}" ]] && { echo >&2 "ERROR: api_id undefined.";  usage 1; }

[[ -z ${filed+x} ]] && { echo >&2 "ERROR: no 'filed' defined"
    exit 1
}
[[ -z ${value+x} ]] && { echo >&2 "ERROR: no 'value' defined"
    exit 1
}

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare DATA=$(
    cat <<EOF
{
    "${filed}":${value}
}
EOF
)

curl -k -X PATCH \
    -H "Authorization: Bearer ${access_token}" \
    -H 'content-type: application/json' \
    -d "${DATA}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/resource-servers/${api_id}
