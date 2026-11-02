#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-10-13
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
#
# Allow (or disallow) anonymous access tokens on a resource server.
# Requires scope: update:resource_servers
##########################################################################################

set -euo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found"; exit 3; }
command -v jq >/dev/null || { echo >&2 "error: jq not found"; exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-l seconds] [-p policy] [-d] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # resource_server id
        -l seconds      # token lifetime for anonymous access tokens (1..86400; Auth0 default 7200)
        -p policy       # anonymous_user policy: deny_all, require_client_grant (default: require_client_grant)
        -d              # disallow anonymous access (sets allow_anonymous_access to false)
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i 6501a2b3c4d5e6f7a8b9c0d1 -l 3600 -p require_client_grant
     $0 -i 6501a2b3c4d5e6f7a8b9c0d1 -d
END
    exit $1
}

declare resource_server_id=''
declare allow=true
declare lifetime=''
declare policy='require_client_grant'
declare opt_verbose=''

while getopts "e:a:i:l:p:dhv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    i) resource_server_id=${OPTARG} ;;
    l) lifetime=${OPTARG} ;;
    p) policy=${OPTARG} ;;
    d) allow=false ;;
    v) opt_verbose=1 ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token:-}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${resource_server_id}" ]] && { echo >&2 "ERROR: resource_server_id undefined."; usage 1; }

if [[ -n "${lifetime}" ]]; then
    [[ "${lifetime}" =~ ^[0-9]+$ ]] && (( lifetime > 0 && lifetime <= 86400 )) \
        || { echo >&2 "ERROR: lifetime must be an integer between 1 and 86400."; usage 1; }
fi

case "${policy}" in
    deny_all | require_client_grant) ;;
    *) echo >&2 "ERROR: invalid policy '${policy}'. Expected: deny_all or require_client_grant (allow_all is not supported for anonymous users)."; usage 1 ;;
esac

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:resource_servers"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<<"${access_token}")

declare lifetime_field=''
[[ -n "${lifetime}" ]] && lifetime_field="\"token_lifetime_for_anonymous_access_tokens\": ${lifetime},"

declare BODY
if [[ "${allow}" == true ]]; then
    BODY=$(cat <<EOL
{
  "allow_anonymous_access": true,
  ${lifetime_field}
  "subject_type_authorization": {
    "anonymous_user": { "policy": "${policy}" }
  }
}
EOL
)
else
    BODY='{ "allow_anonymous_access": false }'
fi

[[ -n "${opt_verbose}" ]] && echo >&2 "${BODY}"

curl -s --request PATCH \
  --url "${AUTH0_DOMAIN_URL}api/v2/resource-servers/${resource_server_id}" \
  --header "authorization: Bearer ${access_token}" \
  --header 'content-type: application/json' \
  --data "${BODY}"
