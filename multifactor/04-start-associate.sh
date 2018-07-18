
declare BODY=$(cat <<EOL
{
    "authenticator_types": ["oob"],
    "oob_channels" : ["sms"],
    "phone_number": "+61400000000"
}
EOL
)

oob_code=`curl -s -H "Authorization: Bearer ${mfa_token}" --header 'content-type: application/json' -d "${BODY}" https://amin01.au.auth0.com/mfa/associate | jq -r '.oob_code'`
echo "export oob_code=\"${oob_code}\""
