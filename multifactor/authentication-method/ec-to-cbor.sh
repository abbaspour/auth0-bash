#!/usr/bin/env bash

##########################################################################################
# Author: Amin Abbaspour
# Date: 2023-01-23
# License: MIT (https://github.com/abbaspour/auth0-bash/blob/master/LICENSE)
##########################################################################################

set -euo pipefail

command -v openssl >/dev/null || { echo >&2 "error: openssh not found";  exit 3; }
command -v node >/dev/null || { echo >&2 "error: node not found";  exit 3; }

function usage() {
    cat <<END >&2
USAGE: $0 [-k private.pem] [-f public.pem] [-v|-h]
        -k file     # private key file
        -f file     # public key file
        -h|?        # usage
        -v          # verbose

eg,
     $0 -k private-key.pem
END
    exit $1
}

declare public_key_file=''

while getopts "k:f:hv?" opt; do
    case ${opt} in
    k) [[ -f "${OPTARG}" ]] || { echo >&2 "error: private key file not found: ${OPTARG}"; exit 4; }
      readonly b=$(basename "${OPTARG}")
      public_key_file="public-${b}"
      openssl ec -in "${OPTARG}" -pubout -out "${public_key_file}"  2>/dev/null ;;
    f) public_key_file=${OPTARG}
      [[ -f "${public_key_file}" ]] || { echo >&2 "error: public key key file not found: ${public_key_file}"; exit 4; } ;;
    v) set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${public_key_file}" ]] && { echo >&2 "ERROR: public key file undefined."; usage 1; }

readonly public_key="$(openssl ec -pubin -noout -text -conv_form uncompressed -in "${public_key_file}" 2>/dev/null | grep -E "^ +.*" | tr -d ' \n' | sed 's/^...//' | tr -d ':')"

readonly x=${public_key:0:${#public_key}/2} # first half
readonly y=${public_key:${#public_key}/2}   # second half

#echo "x = ${x}"
#echo "y = ${y}"

cat <<EOL | node
const cbor = require('cbor');

// ref https://webauthn.guide/
const m = new Map();
m.set(1, 2);  // key type. The value of 2 indicates that the key type is in the Elliptic Curve format.
m.set(3, -7); // algorithm used to generate authentication signatures. The -7 value indicates this authenticator will be using ES256.
m.set(-1, 1); // this key's "curve type". The value 1 indicates the that this key uses the "P-256" curve.
m.set(-2, Buffer.from("${x}", 'hex')); // x-coordinate of the public key
m.set(-3, Buffer.from("${y}", 'hex')); // y-coordinate of the public key

console.log(cbor.encode(m).toString('base64'));
EOL