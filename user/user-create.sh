#!/bin/bash

set -euo pipefail

. .env

randomId() {
    for i in {0..20}; do echo -n $(( RANDOM % 10 )); done
}

declare user_id=$(randomId)

declare BODY=$(cat <<EOL
{
  "user_id": "${user_id}",
  "connection": "custom-ootb",
  "password": "XXXXXX",
  "email": "somebody@gmail.com",
  "username": "somebody",
  "app_metadata": {}
}
EOL
)

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

curl --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/users \
    --header 'content-type: application/json' \
    --data "${BODY}"
