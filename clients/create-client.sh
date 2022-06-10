#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################


set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-n name] [-t type] [-i client_id] [-p PEM] [-c callbacks] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -n name         # client name (e.g. "My Client")
        -t type         # client type: spa, regular_web, native, non_interactive
        -i client_id    # client_id (if accept_client_id_on_creation is on)
        -3              # mark client is 3rd party (default is 1st party)
        -p file         # public key PEM for JWT-CA (if jwt_for_client_auth is on)
        -c uri,uri      # comma seperated list of allowed callback URIs
        -h|?            # usage
        -v              # verbose

eg,
     $0 -n "My App" -t non_interactive
END
  exit $1
}

declare client_id_field=''
declare client_name=''
declare client_type=''
declare is_first_party=true
declare public_key_file=''
declare client_authentication_methods=''
declare callback_uris=''



while getopts "e:a:n:t:i:p:c:3hv?" opt; do
  case ${opt} in
  e) source ${OPTARG} ;;
  a) access_token=${OPTARG} ;;
  n) client_name=${OPTARG} ;;
  t) client_type=${OPTARG} ;;
  i) client_id_field="\"client_id\": \"${OPTARG}\", " ;;
  3) is_first_party=false ;;
  p) public_key_file=${OPTARG} ;;
  c) callback_uris=${OPTARG} ;;
  v) opt_verbose=1 ;; #set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && {
  echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
  usage 1
}

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="create:clients"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${client_name}" ]] && {
  echo >&2 "ERROR: client_name undefined."
  usage 1
}
[[ -z "${client_type}" ]] && {
  echo >&2 "ERROR: client_type undefined."
  usage 1
}

if [[ -n "${public_key_file}" && -f "${public_key_file}" ]]; then
  readonly credential_name=$(basename "${public_key_file}" .pem)
  readonly credential_public_key=$(awk 'NF {sub(/\r/, ""); printf "%s\\n",$0;}' "${public_key_file}")
  client_authentication_methods=$(
    cat <<EOL
  , "client_authentication_methods" : {
    "private_key_jwt" : {
     "credentials": [
       {
          "name": "${credential_name}",
          "credential_type": "public_key",
          "pem": "${credential_public_key}"
       }
     ]
    }
  }
EOL
  )
fi

if [[ -n "${callback_uris}" ]]; then
  uris=$(echo "${callback_uris}" | sed -e 's/,/", "/g')
  callbacks=$(
    cat <<EOL
    , "callbacks": [
      "${uris}"
    ]
EOL
  )
fi

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

declare BODY=$(
  cat <<EOL
{
  ${client_id_field}
  "name": "${client_name}",
  "app_type": "${client_type}",
  "is_first_party": ${is_first_party}
  ${callbacks}
  ${client_authentication_methods}
}
EOL
)

curl -s -k --request POST \
  -H "Authorization: Bearer ${access_token}" \
  --data "${BODY}" \
  --header 'content-type: application/json' \
  --url "${AUTH0_DOMAIN_URL}api/v2/clients" | jq .
