#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2024-01-23
# Reference: https://webauthn.guide/
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -eo pipefail

command -v base64 >/dev/null || { echo >&2 "error: base64 not found";  exit 3; }
command -v hexdump >/dev/null || {  echo >&2 "error: hexdump not found";  exit 3; }
command -v cbor2diag >/dev/null || {  echo >&2 "error: cbor2diag not found; install with: 'npm i -g cbor-cli'";  exit 3; }

[[ $# -lt 1 ]] && { echo >&2 "error: no input passed in params";  exit 2; }

echo "${1}" | base64 --decode | hexdump -v -e '/1 "%02X"' | xargs -0 cbor2diag -x
