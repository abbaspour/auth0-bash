#!/bin/bash

. ./.env

declare AUTH0_DOMAIN='tvnzdevpoc.au.auth0.com'
declare CONNECTION='Username-Password-Authentication'
declare AUTH0_CLIENT_ID='UHqd0F1sr2GE8MnvKD8S88ArJWqQyYrx'

declare DATA=$(cat <<EOF
{
    "client_id":"${AUTH0_CLIENT_ID}", 
    "email":"test.account@signup.com", 
    "password":"XXXXX", 
    "connection":"${CONNECTION}", 
    "user_metadata":{ "plan": "silver", "team_id": "a111" }
}
EOF)

curl --request POST \
  --url https://${AUTH0_DOMAIN}/dbconnections/signup \
  --header 'content-type: application/json' \
  --data "${DATA}"
