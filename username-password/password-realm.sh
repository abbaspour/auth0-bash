client_id=gOpkR4uOpBQmlaubxsdX4n8bi0P5ZOIQ
client_secret=XXXXXX-XXXXX

username='test.account@signup.com'
password='XXXXXX'
#realm='skydir'
realm='Username-Password-Authentication'

#"audience": "https://amin01.au.auth0.com/userinfo"

declare BODY=$(cat <<EOL
{
            "grant_type": "http://auth0.com/oauth/grant-type/password-realm",
            "realm" : "${realm}",
            "scope": "openid profile email",
            "client_id": "${client_id}",
            "client_secret": "${client_secret}",
            "username": "${username}",
            "password": "${password}",
            "audience": "https://amin01.au.auth0.com/api/v2/"
}
EOL
)

curl   --header 'content-type: application/json' -d "${BODY}" https://amin01.au.auth0.com/oauth/token

