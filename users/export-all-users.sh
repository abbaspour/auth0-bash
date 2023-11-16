#!/usr/bin/env bash

declare -r AVAILABLE_SCOPES=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .scope' <<< "${access_token}")
declare -r EXPECTED_SCOPE="read:users"
[[ " $AVAILABLE_SCOPES " == *" $EXPECTED_SCOPE "* ]] || { echo >&2 "ERROR: Insufficient scope in Access Token. Expected: '$EXPECTED_SCOPE', Available: '$AVAILABLE_SCOPES'"; exit 1; }

declare -r AUTH0_DOMAIN_URL=$(jq -Rr 'split(".") | .[1] | @base64d | fromjson | .iss' <<<"${access_token}")


for x in {a..z}; do
  declare -i p=0
  all_done=false

  while [[ $all_done != true ]]; do

    echo "users-${x}-${p}.json"

    curl -k -s --get -H "Authorization: Bearer ${access_token}" \
        -H 'content-type: application/json' \
        --data-urlencode "per_page=100" \
        --data-urlencode "page=$p" \
        --data-urlencode "include_totals=true" \
        --data-urlencode "q=(email:${x}*)" \
        "${AUTH0_DOMAIN_URL}api/v2/users" | jq '.' > "users-${x}-${p}.json"

      declare length=$(jq '.length' "users-${x}-${p}.json")

      p=$((p+1))

      if [[ "${length}" -lt 100 ]]; then all_done=true; fi
  done

done

#jq .users users-*.json | jq -s '.' > all-users.json
jq -s '.' users-*.json | jq -r .users > all-users.json