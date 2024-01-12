#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

echo "" | openssl s_client -showcerts -connect $1:443 -servername $1 2>/dev/null | openssl x509 -text
