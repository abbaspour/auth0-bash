#!/usr/bin/env bash

set -euo pipefail

####
# how to use this? eval `./export-myaccount-at.sh`
####

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

readonly active_env="${DIR}/.env-myaccount"

[[ -f "${active_env}" ]] || { echo >&2 "ERROR: no active .env file found"; exit 3; }

. "${active_env}"

declare MYACCOUNT_SCOPES='read:me:authentication_methods,delete:me:authentication_methods,update:me:authentication_methods,read:me:factors,create:me:authentication_methods'
# connected accounts
MYACCOUNT_SCOPES+=',create:me:connected_accounts,read:me:connected_accounts,delete:me:connected_accounts'

access_token=$("${DIR}/../oidc-bash/resource-owner.sh" -d "${AUTH0_DOMAIN}" -c "${AUTH0_CLIENT_ID}" -x "${AUTH0_CLIENT_SECRET}" \
-u "${USERNAME}" -p "${PASSWORD}" -m -s "${MYACCOUNT_SCOPES}" | jq -r .access_token)
readonly access_token

echo "export access_token='${access_token}'"
