#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-p user_id] [-s id_token] [-v|-h]
        -e file        # .env file location (default cwd)
        -a token       # APIv2 access token with $(update:current_user_identities) scope
        -p user_id     # primary user_id (i.e. current identities)
        -s id_token    # secondary user id_token
        -h|?           # usage
        -v             # verbose

eg,
     $0 -a 'eyJhbGci...' -p 'auth0|xxxx' -s 'eyJhbGc...'
END
    exit $1
}

declare access_token=''
declare user_id=''
declare id_token=''
declare opt_verbose=0

while getopts "e:a:p:s:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    p) user_id=${OPTARG} ;;
    s) id_token=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }

[[ -z "${user_id}" ]] && { echo >&2 "ERROR: user_id undefined";   usage 1; }

[[ -z "${id_token}" ]] && { echo >&2 "ERROR: id_token undefined";  usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare -r BODY=$(cat <<EOL
{
  "link_with": "${id_token}"
}
EOL
)

curl --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/users/${user_id}/identities" \
    --header 'content-type: application/json' \
    --data "${BODY}"
