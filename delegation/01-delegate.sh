##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -euo pipefail

. .env

declare AUTH0_CLIENT='{"name":"auth0.js","version":"9.0.2"}'
declare AUTH0_CLIENT_B64=$(echo -n $AUTH0_CLIENT | base64)

declare BODY=$(
    cat <<EOL
{
    "client_id":"${AUTH0_CLIENT_ID}",
    "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
    "id_token":"${id_token}",
    "target":"${AUTH0_CLIENT_ID}", 
    "scope": "openid",
    "api_type":"aws"
}
EOL
)

curl -v -H "Content-Type: application/json" \
    -d "${BODY}" https://${AUTH0_DOMAIN}/delegation
