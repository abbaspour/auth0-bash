 curl -X POST -H "Authorization: Bearer $access_token" -H "Content-Type: application/json" -d '{"user_id":"auth0|593ebbc61928f760c8ec35fe"}' https://${AUTH0_DOMAIN}/api/v2/tickets/password-change
