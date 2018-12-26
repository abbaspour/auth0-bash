#!/bin/bash

set -euo pipefail

declare -r tenant=amin01.au
declare -r domain=${tenant}.auth0.com
#declare -r param_query='q=(NOT type:fsa)'
declare -r param_query='q=(type:s)'
#declare -r param_query='q=(type:s)'

if [[ -z ${access_token+x} ]]; then 
    echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"; exit 1
fi

#echo "log_id,date,user_id,browser"

curl -s --get -H "Authorization: Bearer ${access_token}" -H 'content-type: application/json' \
 --data-urlencode "${param_query}" \
 https://${domain}/api/v2/logs | jq -r '.[] | "\(.log_id),\(.date),\(.user_id),\(.user_agent)"'
