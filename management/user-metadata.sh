#!/bin/bash

. ./.env

declare USER_ID='auth0%7C5b0dec5bdba02248abd51388'

declare DATA=$(cat <<EOF
{
    "user_metadata":{ "plan": "gold" }
}
EOF)

curl --request PATCH \
  --header "Authorization: Bearer ${access_token}" \
  --url https://${AUTH0_DOMAIN}/api/v2/users/${USER_ID} \
  --header 'content-type: application/json' \
  --data "${DATA}"


