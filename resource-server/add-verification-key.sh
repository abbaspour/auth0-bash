#!/usr/bin/env bash

set -eo pipefail

which curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
which jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }

declare -r DIR=$(dirname ${BASH_SOURCE[0]})

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i id] [-f file] [-k kid] [-v|-h]
        -e file         # .env file location (default cwd)
        -a token        # access_token. default from environment variable
        -i id           # resource-server id
        -f file         # PEM certificate file
        -k kid          # key id
        -h|?            # usage
        -v              # verbose

eg,
     $0 -i 5c1ffff8446f3135f36829ba -k mykid -f ../ca/mykey.local.crt
END
    exit $1
}

declare rs_id=''
declare pem_file=''
declare kid=''

while getopts "e:a:i:f:k:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    i) rs_id=${OPTARG} ;;
    f) pem_file=${OPTARG} ;;
    k) kid=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${access_token}" ]] && {   echo >&2 "ERROR: access_token undefined. export access_token='PASTE' ";  usage 1; }


declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="update:resource_servers"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

[[ -z "${rs_id}" ]] && { echo >&2 "ERROR: rs_id undefined.";  usage 1; }

[[ -z "${kid}" ]] && { echo >&2 "ERROR: kid undefined.";  usage 1; }

[[ -z "${pem_file}" ]] && { echo >&2 "ERROR: pem_file undefined.";  usage 1; }

[[ -f "${pem_file}" ]] || { echo >&2 "ERROR: pem_file missing: ${pem_file}";  usage 1; }


declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

declare -r pem_single_line=$(sed 's/$/\\\\n/' ${pem_file} | tr -d '\n')

declare BODY=$(
    cat <<EOL
{
 "verificationKeys" : [
    {
      "kid": "${kid}",
      "pem": "${pem_single_line}"
    }
   ]
}

EOL
)

curl --request PATCH \
    -H "Authorization: Bearer ${access_token}" \
    --url ${AUTH0_DOMAIN_URL}api/v2/resource-servers/${rs_id} \
    --header 'content-type: application/json' \
    --data "${BODY}"
