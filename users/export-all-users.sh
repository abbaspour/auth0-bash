#!/usr/bin/env bash

command -v curl >/dev/null || { echo >&2 "error: curl not found";  exit 3; }
command -v jq >/dev/null || {  echo >&2 "error: jq not found";  exit 3; }
command -v mktemp >/dev/null || {  echo >&2 "error: mktemp not found";  exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-e env] [-a access_token] [-i user_id] [-v|-h]
        -e file     # .env file location (default cwd)
        -a token    # access_token. default from environment variable
        -p prefix   # start end prefix. default is ''
        -h|?        # usage
        -v          # verbose

eg,
     $0 -s pa -e pz
END
    exit $1
}

declare prefix=''

while getopts "e:a:p:hv?" opt; do
    case ${opt} in
    e) source ${OPTARG} ;;
    a) access_token=${OPTARG} ;;
    p) prefix=${OPTARG} ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:users"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")

readonly tmp=$(mktemp --suffix json)

declare -i total_exported=0

# todo: include other valid email characters like; . _ - + () 0..9
for x in {a..z}; do
  declare -i p=0
  all_done=false

  echo -n "starting with ${prefix}${x} "
  while [[ $all_done != true ]]; do
    declare file="users-${prefix}-${x}-${p}.json"

    curl -k -s --get -H "Authorization: Bearer ${access_token}" \
        -H 'content-type: application/json' \
        --data-urlencode "per_page=100" \
        --data-urlencode "page=$p" \
        --data-urlencode "include_totals=true" \
        --data-urlencode "q=(email:${prefix}${x}*)" \
        "${AUTH0_DOMAIN_URL}api/v2/users" | jq '.' > "${tmp}"

      declare -i length=$(jq '.length' "${tmp}")
      declare -i total=$(jq '.total' "${tmp}")

      if [[ "${p}" -eq 0 ]]; then
          [[ "${total}" -ge 1000 ]] && echo "WARNING. maximum reached. run again with: -p ${prefix}${x}"
          echo -n "(${total}) "
      fi
      total_exported=$((total_exported + length))

      jq -r '.users' "${tmp}" > "${file}"
      echo -n "$p "
      if [[ "${length}" -lt 100 ]]; then all_done=true; fi
      p=$((p+1))
  done
  echo
done

echo "Total exported: ${total_exported}"

jq -s add "users-${prefix}-*.json" >> "all-users${prefix}.json"

readonly total_in_file=$(jq length "all-users${prefix}.json")

echo "Total in file : ${total_in_file}"
