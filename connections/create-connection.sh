#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-f file] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -f file     # connection definition JSON file
        -m metadata # SAML IdP metadata xml file
        -n name     # connection name
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
    exit $1
}

declare json_file=''
declare metadata_file=''
declare name=''

while getopts "e:a:f:m:n:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    f) json_file=${OPTARG} ;;
    m) metadata_file=${OPTARG} ;;
    n) name=${OPTARG} ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:connections"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

if [[ -n "${metadata_file}" ]]; then
  [[ -f "${metadata_file}" ]] || { echo >&2 "ERROR: metadata missing: ${metadata_file}";  usage 1; }
  [[ -z "${name}" ]] && name=$(basename "${metadata_file}" '.xml' | sed 's/ /-/g')
  metadata_content=$(sed 's/"/\\"/g' "${metadata_file}")
  BODY=$(cat <<EOL
{
  "options": {
   "metadataXml": "${metadata_content}"
  },
  "strategy": "samlp",
  "name": "${name}",
  "enabled_clients": []
}
EOL
)
else
  [[ -z "${json_file}" ]] && { echo >&2 "ERROR: json_file undefined.";  usage 1; }
  [[ -f "${json_file}" ]] || { echo >&2 "ERROR: json_file missing: ${json_file}";  usage 1; }
  BODY=$(cat "${json_file}")
fi

curl --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --url "${AUTH0_DOMAIN_URL}api/v2/connections" \
    --header 'content-type: application/json' \
    --data "${BODY}"
