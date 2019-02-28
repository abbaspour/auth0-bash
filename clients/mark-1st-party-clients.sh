#!/bin/bash

###
# have an `access_token` env variable with read:client and update:client scopes.
#
###

./list-clients.sh -1 | jq -r '.[].client_id' | xargs -L1 -I% bash -c "./update-client-metadata.sh -i % -m 3rdparty:false; sleep 1"
