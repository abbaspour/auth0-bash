#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

echo "" | openssl s_client -showcerts -connect $1:443 -servername $1 2>/dev/null | openssl x509 -text
