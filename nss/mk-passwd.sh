#!/usr/bin/env bash

set -eo pipefail

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

declare PASSWD_OUTPUT='passwd'
declare SHADOW_OUTPUT='shadow'
declare FIELD_UID='app_metadata.uid'
declare FIELD_GID='app_metadata.gid'
declare FIELD_DIR='app_metadata.homeDir'
declare FIELD_SHL='app_metadata.shell'
declare FIELD_USERNAME='email'
declare CONNECTION_NAME=''

declare VALUE_GID=''
declare VALUE_HOME_PREFIX='/home/'
declare VALUE_DIR=''
declare VALUE_SHL='/bin/bash'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-q query] [-2|-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -c name     # optional connection name.
        -u uid      # UID field. default is "${FIELD_UID}"
        -g gid      # GID field. default is "${FIELD_GID}"
        -d dir      # Home Directory field. default is "${FIELD_DIR}"
        -s shell    # Shell field. default is "${FIELD_SHL}"
        -G gid      # Fixed GID value
        -D dir      # Fixed Home directory
        -S shell    # Fixed shell value default is "${VALUE_SHL}"
        -p prefix   # Home Dir prefix. default is "${VALUE_HOME_PREFIX}"
        -q query    # Optional query string
        -U          # username mode. default is email mode.
        -o output   # passwd output file name. default is "${PASSWD_OUTPUT}"
        -O output   # shadow output file name. default is "${SHADOW_OUTPUT}"
        -h|?        # usage
        -v          # verbose

eg,
     $0 -G 1000 -c UNIX
END
    exit $1
}

declare query=''
declare opt_verbose=0
declare passwd_file=${PASSWD_OUTPUT}
declare shadow_file=${SHADOW_OUTPUT}

while getopts "e:a:c:u:g:d:s:G:D:S:p:q:o:O:Uhv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    c) CONNECTION_NAME=${OPTARG} ;;
    u) FIELD_UID=${OPTARG} ;;
    g) FIELD_GID=${OPTARG} ;;
    d) FIELD_DIR=${OPTARG} ;;
    s) FIELD_SHL=${OPTARG} ;;
    G) VALUE_GID=${OPTARG} ;;
    D) VALUE_DIR=${OPTARG} ;;
    S) VALUE_SHL=${OPTARG} ;;
    p) VALUE_HOME_PREFIX=${OPTARG} ;;
    q) query=${OPTARG} ;;
    o) passwd_file=${OPTARG} ;;
    O) shadow_file=${OPTARG} ;;
    U) FIELD_USERNAME='username' ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

declare -r per_page=100

[[ -z ${access_token+x} ]] && { echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"
    exit 1
}

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:users"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare fields="${FIELD_USERNAME},user_id,${FIELD_UID},${FIELD_GID},${FIELD_DIR},${FIELD_SHL},given_name"

[[ -z ${CONNECTION_NAME+x} ]] || query+="identities.connection:\"${CONNECTION_NAME}\""

declare page=0
declare total=1

rm -f ${passwd_file}
rm -f ${shadow_file}

#        --data-urlencode "q=(${query})" \
while [[ $((per_page * page)) -lt ${total} ]]; do
    output=$(curl -s --get -H "Authorization: Bearer ${access_token}" \
        -H 'content-type: application/json' \
        --data-urlencode "page=${page}" \
        --data-urlencode "per_page=${per_page}" \
        --data-urlencode "include_totals=true" \
        --data-urlencode "sort=${FIELD_USERNAME}:1" \
        --data-urlencode "search_engine=v3" \
        --data-urlencode "fields=${fields}" \
        --data-urlencode "include_fields=true" \
        ${AUTH0_DOMAIN_URL}api/v2/users)
    total=$(echo ${output} | jq -r '.total')
    page=$((page + 1)) echo ${output} | jq -r ".users[] | select(.${FIELD_UID} != null and .${FIELD_GID} != null) | \"\(.${FIELD_USERNAME}):x:\(.${FIELD_UID}):\(.${FIELD_GID}):\(.name):\(.${FIELD_DIR}):\(.${FIELD_SHL})\"" >>${passwd_file} echo ${output} | jq -r ".users[] | select(.${FIELD_UID} != null and .${FIELD_GID} != null) | \"\(.${FIELD_USERNAME}):*:18052:0:99999:7:::\"" >>${shadow_file}
done
