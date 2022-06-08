##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

[[ $# -lt 1 ]] && jwt=$access_token || jwt=$1
echo $jwt | awk -F. '{print $2}' | base64 -d -w0 2>/dev/null | jq '.'
