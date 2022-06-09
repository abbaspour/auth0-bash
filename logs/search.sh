##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -euo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-q query] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -q query    # query
        -h|?        # usage
        -v          # verbose

eg,
     $0 -q type:s
     $0 -q 'NOT type:fsa'
END
    exit $1
}

declare query=''

while getopts "e:a:q:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    q) query=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z ${access_token+x} ]] && {
    echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"
    exit 1
}
declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare param_query=''
[[ -n ${query} ]] && param_query="q=(${query})"

curl -s --get -H "Authorization: Bearer ${access_token}" \
    -H 'content-type: application/json' \
    --data-urlencode "${param_query}" \
    ${AUTH0_DOMAIN_URL}api/v2/logs
