#!/usr/bin/env bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

command -v curl >/dev/null || {
  echo >&2 "error: curl not found"
  exit 3
}
command -v jq >/dev/null || {
  echo >&2 "error: jq not found"
  exit 3
}
function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-p color] [-b background-color] [-i favicon-url] [-l logo-url] [-f font-url]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -p color    # primary color
        -b color    # background color
        -i url      # icon url
        -l url      # logo url
        -f url      # font url
        -h|?        # usage
        -v          # verbose

eg,
     $0 -f "enable_client_connections":true
END
  exit ${1}
}

declare primary=''
declare page_background=''
declare favicon_url=''
declare logo_url=''
declare font_url=''

while getopts "e:a:p:b:i:l:f:hv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  a) access_token=${OPTARG} ;;
  p) primary=${OPTARG} ;;
  b) page_background=${OPTARG} ;;
  i) favicon_url=${OPTARG} ;;
  l) logo_url=${OPTARG} ;;
  f) font_url=${OPTARG} ;;
  v) opt_verbose=1 ;; #set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:branding"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

declare BODY=$(cat <<EOL
{
  "colors": {
    "primary": "${primary}",
    "page_background": "${page_background}"
  },
  "favicon_url": "${favicon_url}",
  "logo_url": "${logo_url}",
  "font": {
    "url": "${font_url}"
  }
}
EOL
)

curl --request PATCH \
  -H "Authorization: Bearer ${access_token}" \
  --data "${BODY}" \
  --header 'content-type: application/json' \
  --url "${AUTH0_DOMAIN_URL}api/v2/branding"
