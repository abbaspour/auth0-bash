#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

curl -sL https://cdn.auth0.com/extensions/extensions.json | jq -r '.[] | "\(.name) \t \(.version)"'
