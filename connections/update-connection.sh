#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i connect_id] [-f file] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i id       # connection_id
        -f file     # connection definition JSON file
        -d          # make connection domain level
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
    exit $1
}

declare json_file=''
declare connection_id=''
declare mk_domain=0

while getopts "e:a:i:f:dhv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        i) connection_id=${OPTARG};;
        f) json_file=${OPTARG};;
        d) mk_domain=1;;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${connection_id}" ]] && { echo >&2 "ERROR: connection_id undefined."; usage 1; }
if [[ ${mk_domain} -ne 0 ]]; then
    json_file=`mktemp`
    echo '{"is_domain_connection": true}' > ${json_file}
fi
[[ -z "${json_file}" ]] && { echo >&2 "ERROR: json_file undefined."; usage 1; }
[[ -f "${json_file}" ]] || { echo >&2 "ERROR: json_file missing: ${json_file}"; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(echo ${access_token} | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/connections/${connection_id} \
    --header 'content-type: application/json' \
    --data @${json_file}
