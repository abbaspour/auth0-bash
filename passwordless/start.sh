#!/bin/bash

declare -r client_id='aIioQEeY7nJdX78vcQWDBcAqTABgKnZl'
declare -r email='somebody@gmail.com'

declare data=$(cat <<EOL
{
    "client_id":"${client_id}", 
    "connection":"email", 
    "email":"${email}", 
    "send":"link", 
    "authParams":{"scope": "openid email","state": "SOME_STATE", "response_type" : "code"}
}
EOL
)

curl --request POST \
  --url 'https://amin01.au.auth0.com/passwordless/start' \
  --header 'content-type: application/json' \
  --data "${data}"

