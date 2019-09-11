#!/bin/bash

. ./.env

declare AUTH0_DOMAIN='XXXX.auth0.com'
declare CONNECTION='Username-Password-Authentication'
declare AUTH0_CLIENT_ID='XXXX'

declare DATA=$(cat <<EOF
{
    "client_id":"${AUTH0_CLIENT_ID}",
    "email":"user@gmail.com",
    "password":"XXXXX",
    "connection":"${CONNECTION}",
    "user_metadata":{ }
}
EOF)

curl --request POST \
  --url https://${AUTH0_DOMAIN}/dbconnections/signup \
  --header 'content-type: application/json' \
  --data "${DATA}"
