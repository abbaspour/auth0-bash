##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

declare rule_stage='login_success'

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -s stage    # filter by stage: login_success, login_failure, pre_authorize (defaults to "${rule_stage}") 
        -p          # pretty print
        -h|?        # usage
        -v          # verbose

eg,
     $0 
END
    exit $1
}

declare JQ_SCRIPT='.'
declare pp=0

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

while getopts "e:a:s:phv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    s) rule_stage=${OPTARG} ;;
    p)
        pp=1
        JQ_SCRIPT='.[] | "\(.order) \t \(.stage) \t \(.id) \t \(.name)"'
        ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {
    echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
    usage 1
}

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

[[ -n "${pp}" ]] && echo -e "Order \t Stage \t\t ID \t\t\t Name"

curl -s -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/rules?stage=${rule_stage} | jq -r "${JQ_SCRIPT}" #| sort -n
