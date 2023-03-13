#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -eo pipefail

command -v node >/dev/null || { echo >&2 "error: node not found";  exit 3; }

declare -i iterations=10000
declare -i keylen=20
declare algorithm='sha256'

function usage() {
    cat <<END >&2
USAGE: $0 [-e file] [-f file] [-v|-h]
        -p password    # password
        -s salt        # salt (base64). defaults to a random value
        -i iter        # iterations (defaults to $iterations)
        -l keylen      # output key length (defaults to $keylen)
        -a algorithm   # digest algorithm such as sha1, sha256, md, etc (defaults to $algorithm)
        -h|?           # usage
        -v             # verbose

eg,
     $0 -p hardpass -s mysalt -i 10000 -l 20 -a sha1    # this is Gigya defaults
END
    exit $1
}

declare password=''
declare salt=$(openssl rand -base64 12)

while getopts "p:s:i:l:a:hv?" opt; do
    case ${opt} in
    p) password=${OPTARG} ;;
    s) salt=${OPTARG} ;;
    i) iterations=${OPTARG} ;;
    l) keylen=${OPTARG} ;;
    a) algorithm=${OPTARG} ;;
    v) set -x ;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${password}" ]] && { echo >&2 "ERROR: password undefined";  usage 1; }


declare -r key=$(cat <<EOL | node
const crypto = require('crypto');
const key = crypto.pbkdf2Sync("${password}", Buffer.from("${salt}", 'base64'), ${iterations}, ${keylen}, "${algorithm}");
console.log(key.toString('base64'));
EOL
)

declare -r salt_phc=$(echo "${salt}" | tr -d '=')
declare -r key_phc=$(echo "${key}" | tr -d '=')

echo "\$pbkdf2-${algorithm}\$i=${iterations},l=${keylen}\$${salt_phc}\$${key_phc}"
