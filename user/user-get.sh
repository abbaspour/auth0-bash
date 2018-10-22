tenant=amin01.au

# https://auth0.com/docs/users/search/v3#migrate-from-search-engine-v2-to-v3
id=$1

curl -s --get -H "Authorization: Bearer ${access_token}" -H 'content-type: application/json' \
    https://${tenant}.auth0.com/api/v2/users/${id}
