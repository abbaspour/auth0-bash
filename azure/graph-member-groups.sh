#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

declare uid='USERNAME@ORG.onmicrosoft.com'

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: no onmicrosoft access_token present. export it."
    exit 1
}

curl 'https://graph.windows.net/myorganization/users/${uid}/getMemberGroups?api-version=1.6' \
    -H 'Accept: application/json, text/plain, */*' \
    -H 'Referer: https://graphexplorer.azurewebsites.net/' \
    -H 'Origin: https://graphexplorer.azurewebsites.net' \
    -H "Authorization: Bearer ${access_token}" \
    -H 'Content-Type: application/json;charset=UTF-8' \
    --data-binary $'{"securityEnabledOnly" : true}'
