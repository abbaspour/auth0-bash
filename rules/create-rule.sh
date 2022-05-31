#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

declare rule_stage='login_success'
declare rule_order=1

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-f file] [-n name] [-o order] [-s stage] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -f file     # Rule script file
        -n name     # Name
        -o order    # Execution order (default to "${rule_order}")
        -s stage    # stage of: login_success, login_failure, pre_authorize (defaults to "${rule_stage}")
        -h|?        # usage
        -v          # verbose

eg,
     $0 -n test -f test.js -o 10 
END
    exit $1
}

declare script_file=''
declare opt_verbose=''
declare rule_name=''

while getopts "e:a:f:n:o:s:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        f) script_file=${OPTARG};;
        n) rule_name=${OPTARG};;
        o) rule_order=${OPTARG};;
        s) rule_stage=${OPTARG};;
        v) opt_verbose='-v';; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${access_token}" ]] && { echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "; usage 1; }
[[ -z "${rule_name}" ]] && { echo >&2 "ERROR: rule_name undefined."; usage 1; }
[[ -z "${script_file}" ]] && { echo >&2 "ERROR: script_file undefined."; usage 1; }
[[ -f "${script_file}" ]] || { echo >&2 "ERROR: script_file missing: ${json_file}"; usage 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<< "${access_token}")

declare script_single_line=`sed 's/$/\\\\n/' ${script_file} | tr -d '\n'`

declare BODY=$(cat <<EOL
{
  "name": "${rule_name}",
  "script": "${script_single_line}",
  "order": ${rule_order},
  "stage": "${rule_stage}",
  "enabled": true
}
EOL
)

curl ${opt_verbose} -H "Authorization: Bearer ${access_token}" \
  --url ${AUTH0_DOMAIN_URL}api/v2/rules \
  --header 'content-type: application/json' \
  --data "${BODY}"

