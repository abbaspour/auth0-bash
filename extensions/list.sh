##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

curl -sL https://cdn.auth0.com/extensions/extensions.json | jq -r '.[] | "\(.name) \t \(.version)"'
