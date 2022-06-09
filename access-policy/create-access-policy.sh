##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -euo pipefail

which curl >/dev/null || {
    echo >&2 "error: curl not found"
    exit 3
}
which jq >/dev/null || {
    echo >&2 "error: jq not found"
    exit 3
}

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-A access_token] [-c client_id] [-a audience] [-s scopes] [-m|-v|-h]
        -e file         # .env file location (default cwd)
        -A token        # access_token. default from environment variable
        -c id           # client_id
        -a audience     # resource server API audience
        -s scopes       # scopes to grant
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i some_api -a other_api -s list:things,update:things
END
    exit $1
}

declare client_id=''
declare audience=''
declare api_scopes=''

while getopts "e:A:c:a:s:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    A) access_token=${OPTARG} ;;
    c) client_id=${OPTARG} ;;
    a) audience=${OPTARG} ;;
    s) api_scopes=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {
    echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
    usage 1
}
declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")
[[ -z "${client_id}" ]] && {
    echo >&2 "ERROR: client_id undefined."
    usage 1
}
[[ -z "${audience}" ]] && {
    echo >&2 "ERROR: audience undefined."
    usage 1
}
[[ -z "${api_scopes}" ]] && {
    echo >&2 "ERROR: api_scopes undefined."
    usage 1
}

for s in $(echo ${api_scopes} | tr ',' ' '); do
    scopes+="\"${s}\","
done
scopes=${scopes%?}

declare BODY=$(
    cat <<EOL
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
    --url ${AUTH0_DOMAIN_URL}api/v2/access-policies
