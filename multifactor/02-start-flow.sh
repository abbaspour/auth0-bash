#!/bin/bash

declare BODY=$(cat <<EOL
{
	"grant_type": "http://auth0.com/oauth/grant-type/password-realm",
	"client_id": "rIOP4PF60u72M1tqnXBuZl8Utaql1PNp",
    "client_secret": "XXXXX",
	"username": "john.doe2@gmail.com",
	"password": "secret",
	"scope": "openid email",
	"realm": "Username-Password-Authentication"
}
EOL
)

curl --header 'content-type: application/json' -d "${BODY}" https://amin01.au.auth0.com/oauth/token

exit 0 

export mfa_token=`curl -s --header 'content-type: application/json' -d "${BODY}" https://amin01.au.auth0.com/oauth/token | jq -r '.mfa_token'`

echo "export mfa_token=\"${mfa_token}\""
