 curl -X POST -H "Authorization: Bearer $access_token" -H "Content-Type: application/json" -d '{"user_id":"auth0|5b5e65d30368302c7d1223a6"}' https://${AUTH0_DOMAIN}/api/v2/tickets/password-change
