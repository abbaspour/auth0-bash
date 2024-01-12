#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

sed 's|\\|\\\\|g;s/$/\\n/g' $1 | tr -d '\n'
echo
