#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

###
# have an `access_token` env variable with read:client and update:client scopes.
#
###

./list-clients.sh -1 | jq -r '.[].client_id' | xargs -L1 -I% bash -c "./update-client-metadata.sh -i % -m 3rdparty:false; sleep 1"
