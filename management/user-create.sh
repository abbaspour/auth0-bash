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
  "connection": "Username-Password-Authentication",
  "password": "XXXXXX"
  "email": "somebody@gmail.com",
  "username": "somebody",
  "app_metadata": {}
}
EOL
)


curl --request POST \
    -H "Authorization: Bearer ${access_token}" \
    --url https://${AUTH0_DOMAIN}/api/v2/users \
    --header 'content-type: application/json' \
    --data "${BODY}"
