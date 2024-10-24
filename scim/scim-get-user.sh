SCIM_ENDPOINT='https://amin.jp.auth0.com/scim/v2/connections/con_xxx'
SCIM_TOKEN='xxxx'
user_id='samlp|xxx|yyy'

curl -H "Authorization: Bearer ${SCIM_TOKEN}" "${SCIM_ENDPOINT}/users/${user_id}"