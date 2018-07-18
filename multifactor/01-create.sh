#!/bin/bash

declare BODY=$(cat <<EOL
{
  "connection": "Username-Password-Authentication",
  "email": "john.doe2@gmail.com",
  "password": "XXXX",
  "email_verified": true,
  "verify_email": false
}
EOL
)

curl -H "Authorization: Bearer ${access_token}"  --header 'content-type: application/json' -d "${BODY}" https://amin01.au.auth0.com/api/v2/users
