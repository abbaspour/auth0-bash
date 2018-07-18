
declare BODY=$(cat <<EOL
{
	"client_id": "rIOP4PF60u72M1tqnXBuZl8Utaql1PNp",
    "client_secret": "XXXX",
    "challenge_type": "oob",
	"mfa_token": "${mfa_token}"
}
EOL
)

curl -s --header 'content-type: application/json' -d "${BODY}" https://amin01.au.auth0.com/mfa/challenge
