#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2026-11-25
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
#
# List, add or remove domains in the personal_agent_protocol_company_domains tenant setting.
# Without -A or -R the current domains are listed.
# The current list is read first, so existing domains not mentioned are preserved.
# Requires scopes: read:tenant_settings (list), plus update:tenant_settings (add/remove)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

declare add_domains=''
declare remove_domains=''

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-A domain]... [-R domain]... [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -A domain   # domain to add (repeatable, or comma separated)
        -R domain   # domain to remove (repeatable, or comma separated)
        -h|?        # usage
        -v          # verbose

Without -A or -R the current domains are listed.

eg,
     $0
     $0 -A shop.example
     $0 -A shop.example,corp.example -R old.example
END
    exit $1
}

while getopts "e:a:A:R:hv?" opt; do
    case ${opt} in
    e) source "${OPTARG}" ;;
    a) access_token=${OPTARG} ;;
    A) add_domains+="${OPTARG}," ;;
    R) remove_domains+="${OPTARG}," ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }

# without -A or -R the script only lists the current domains
declare list_only=''
[[ -z "${add_domains}" && -z "${remove_domains}" ]] && list_only=1

declare EXPECTED_SCOPES='read:tenant_settings'
[[ -z "${list_only}" ]] && EXPECTED_SCOPES+=' update:tenant_settings'

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .scope' <<< "${access_token}")
for EXPECTED_SCOPE in ${EXPECTED_SCOPES}; do
    [[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }
done

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".")[1] | gsub("-";"+") | gsub("_";"/") | gsub("%3D";"=") | @base64d | fromjson | .iss' <<<"${access_token}")

# the PATCH replaces the whole array, so start from the current value
declare -r SETTINGS=$(curl -s -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/tenants/settings?fields=personal_agent_protocol_company_domains&include_fields=true")

jq -e 'has("statusCode") | not' >/dev/null <<<"${SETTINGS}" || { echo >&2 "ERROR: failed to read tenant settings: ${SETTINGS}"; exit 1; }

if [[ -n "${list_only}" ]]; then
    jq '{personal_agent_protocol_company_domains: (.personal_agent_protocol_company_domains // [])}' <<<"${SETTINGS}"
    exit 0
fi

declare -r BODY=$(jq -c \
    --arg add "${add_domains}" \
    --arg remove "${remove_domains}" \
    '
      def domains: split(",") | map(select(length > 0));
      (.personal_agent_protocol_company_domains // []) as $current
      | ($remove | domains) as $rm
      | { personal_agent_protocol_company_domains:
          (reduce ($add | domains)[] as $d ($current; if any(.[]; . == $d) then . else . + [$d] end)
           | map(select(. as $x | $rm | index($x) | not))) }
    ' <<<"${SETTINGS}")

curl -s -H "Authorization: Bearer ${access_token}" \
    --request PATCH \
    --data "${BODY}" \
    --header 'content-type: application/json' \
    --url "${AUTH0_DOMAIN_URL}api/v2/tenants/settings" | jq '{personal_agent_protocol_company_domains}'
