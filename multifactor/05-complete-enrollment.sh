
declare BODY=$(cat <<EOL
{
    "grant_type": "http://auth0.com/oauth/grant-type/mfa-oob",
	"client_id": "rIOP4PF60u72M1tqnXBuZl8Utaql1PNp",
    "client_secret": "XXXX",
    "oob_code": "${oob_code}",
    "mfa_token": "${mfa_token}",
	"binding_code": "XXXXX"
}
EOL
)

curl -s --header 'content-type: application/json' -d "${BODY}" https://amin01.au.auth0.com/oauth/token
