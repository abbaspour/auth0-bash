#!/usr/bin/env bash

set -euo pipefail

####
# how to use this? eval `./export-management-at.sh`
####

readonly DIR=$(dirname "${BASH_SOURCE[0]}")

#readonly active_env="${DIR}/.env"
#readonly active_env="${DIR}/.env-atl-sus2"
#readonly active_env="${DIR}/.env-amin01-sus2"
#readonly active_env="${DIR}/.env-amin01-api-explorer"
readonly active_env="${DIR}/.env-abbaspour-api-explorer"
#readonly active_env="${DIR}/.env-atl-sus2"
#readonly active_env="${DIR}/.env-vivaldi"
#readonly active_env="${DIR}/.env-layer0-amin"

[[ -f "${active_env}" ]] || { echo >&2 "ERROR: no active .env file found"; exit 3; }

readonly at=$("${DIR}"/client-credentials.sh -e "${active_env}" -m | jq -r .access_token)

echo "export access_token=$at"
