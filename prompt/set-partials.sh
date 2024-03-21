#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-02-27
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-p prompt] [-t template]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -p prompt   # prompt name
        -t template # HTML page template for prompt
        -h|?        # usage
        -v          # verbose

eg,
     $0 -p customized-consent -t '<div>Operation Details</div>'
END
    exit ${1}
}

declare prompt=''
declare template=''

while getopts "e:a:p:t:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    p) prompt="${OPTARG}" ;;
    t) template=${OPTARG//\"/\\\"}  ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:prompts"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${prompt}" ]] && { echo >&2 "ERROR: prompt undefined.";  usage 1; }
[[ -z "${template}" ]] && { echo >&2 "ERROR: template undefined.";  usage 1; }


readonly AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

readonly BODY=$(cat <<EOL
{
  "${prompt}": {
    "form-content": "${template}"
  }
}
EOL
)

curl --request PUT \
    -H "Authorization: Bearer ${access_token}" \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/prompts/${prompt}/partials"
