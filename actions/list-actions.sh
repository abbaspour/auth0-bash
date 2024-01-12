#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-T trigger_id] [-n name] [-d (true|false)] [-i (true|false)] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -T trigger_id   # trigger id. eg: post-login, pre-user-registration
        -n name         # action name
        -d deployed     # deployed status. should be true or false
        -i installed    # installed vs custom actions. should be true or false
        -h|?            # usage
        -v              # verbose

eg,
     $0
     $0 -T post-login -d true
END
    exit $1
}

declare trigger_id=''
declare action_name=''
declare deployed=''
declare installed=''

while getopts "e:a:T:n:d:i:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    T) trigger_id=${OPTARG} ;;
    n) action_name=${OPTARG} ;;
    d) deployed=${OPTARG} ;;
    i) installed=${OPTARG} ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:actions"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

declare args=()

[[ ! -z $trigger_id ]] && args+=( "--data-urlencode" "triggerId=${trigger_id}" )
[[ ! -z $action_name ]] && args+=( "--data-urlencode" "actionName=${action_name}" )
[[ ! -z $deployed ]] && args+=( "--data-urlencode" "deployed=${deployed}" )
[[ ! -z $installed ]] && args+=( "--data-urlencode" "installed=${installed}" )

curl -s --get -H "Authorization: Bearer ${access_token}" \
    "${args[@]}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/actions/actions | jq .
