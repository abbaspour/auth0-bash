tenant=amin01.au

# https://auth0.com/docs/users/search/v3#migrate-from-search-engine-v2-to-v3

#param_query='q=email_verified:false OR NOT _exists_:email_verified'    
param_query='q=(NOT _exists_:logins_count OR logins_count:0)'
#param_query='q=(created_at:[2017-12-01 TO 2017-12-31])'
param_version='search_engine=v3'

curl -v -s --get -H "Authorization: Bearer ${access_token}" -H 'content-type: application/json' \
    --data-urlencode "${param_query}" --data-urlencode "${param_version}" \
    https://${tenant}.auth0.com/api/v2/users
