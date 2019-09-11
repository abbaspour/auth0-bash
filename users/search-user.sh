#!/bin/bash

set -euo pipefail

declare -r DIR=$(dirname ${BASH_SOURCE[0]})
[[ -f ${DIR}/.env ]] && . ${DIR}/.env

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-q query] [-2|-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -q query    # query
        -2          # use v2 search engine (default is v3)
        -h|?        # usage
        -v          # verbose

eg,
     $0 -q type:s
     $0 -q 'NOT type:fsa'
END
    exit $1
}

declare query=''
declare search_engine='v3'
declare opt_verbose=0

while getopts "e:a:q:2hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        q) query=${OPTARG};;
        2) search_engine='v2';;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z ${access_token+x} ]] && { echo >&2 -e "ERROR: no 'access_token' defined. \nopen -a safari https://manage.auth0.com/#/apis/ \nexport access_token=\`pbpaste\`"; exit 1; }
declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

declare param_query=''
[[ -n ${query} ]] && param_query="q=(${query})"

declare param_version="search_engine=${search_engine}"

curl -k -s --get -H "Authorization: Bearer ${access_token}" \
 -H 'content-type: application/json' \
 --data-urlencode "${param_query}" \
 --data-urlencode "${param_version}" \
  ${AUTH0_DOMAIN_URL}api/v2/users #| awk -F: '/^x-ratelimit-reset/{print $2}' | xargs -L 1 -I% date -d @%


#tenant=amin01.au
#
## https://auth0.com/docs/users/search/v3#migrate-from-search-engine-v2-to-v3
#
##param_query='q=email_verified:false OR NOT _exists_:email_verified'
##param_query='q=(NOT _exists_:logins_count OR logins_count:0)'
##param_query='q=(NOT app_metadata.role:"b")'
#param_query='q=(NOT _exists_:app_metadata.memberships)'
##param_query='q=(created_at:[2017-12-01 TO 2017-12-31])'
#param_version='search_engine=v3'
#
#curl -s --get -H "Authorization: Bearer ${access_token}" -H 'content-type: application/json' \
#    --data-urlencode "${param_query}" --data-urlencode "${param_version}" \
#    https://${tenant}.auth0.com/api/v2/users
