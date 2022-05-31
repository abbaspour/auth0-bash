#!/bin/bash

set -eo pipefail
declare -r DIR=$(dirname ${BASH_SOURCE[0]})

[[ -f ${DIR}/.env ]] && . ${DIR}/.env

function usage() {
  cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i domain_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -i {id}     # custom domain id
        -h|?        # usage
        -v          # verbose

eg,
     $0
END
  exit $1
}

declare query=''
declare -i opt_verbose=0

while getopts "e:a:i:hv?" opt; do
  case ${opt} in
  e) source "${OPTARG}" ;;
  a) access_token=${OPTARG} ;;
  i) query="/${OPTARG}" ;;
  v) opt_verbose=1 ;; #set -x;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

[[ -z "${access_token}" ]] && {
  echo >&2 "ERROR: access_token undefined. export access_token='PASTE' "
  usage 1
}

declare -r AUTH0_DOMAIN_URL=$(echo "${access_token}" | awk -F. '{print $2}' | base64 -di 2>/dev/null | jq -r '.iss')

curl -k -s -H "Authorization: Bearer ${access_token}" \
  --url "${AUTH0_DOMAIN_URL}api/v2/custom-domains${query}" | jq '.'
