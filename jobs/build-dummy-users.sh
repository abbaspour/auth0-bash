##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

#!/bin/bash

set -eo pipefail

declare -i bc_rounds=10
declare domain='contoso.com'

function usage() {
  cat <<END >&2
USAGE: $0 [-c number]
        -c number   # number of dummy users
        -p prefix   # prefix
        -x password # password
        -s salt     # password salt prefix
        -S salt     # password salt suffix
        -a name     # password hash algorithm; bcrypt (default), md4, md5, ldap, sha1, sha256, sha512, argon2, pbkdf2-sha1, pbkdf2-sha256
        -r round    # bcrypt rounds. default is $bc_rounds
        -V          # set email_verified to true
        -d domain   # email domain. default is ${domain}
        -h          # help

eg,
     $0 -c 10
END
  exit $1
}

declare count=1
declare prefix=''
declare is_email_verified='false'
declare custom_password_hash=0
declare algorithm='bcrypt'
declare salt_prefix=''
declare salt_suffix=''
declare salt_position=''
declare salt_enc_prefix=''
declare salt_enc_suffix=''

while getopts "e:a:c:p:d:x:r:a:s:S:Vhv?" opt; do
  case ${opt} in
  e) source ${OPTARG} ;;
  a) algorithm=${OPTARG} ;;
  c) count=${OPTARG} ;;
  p) prefix=${OPTARG} ;;
  x) password=${OPTARG} ;;
  d) domain=${OPTARG} ;;
  r) round=${OPTARG} ;;
  s)
    salt_prefix=${OPTARG}
    salt_position='prefix'
    salt_enc_prefix=$(echo -n "${OPTARG}" | openssl enc -A -base64)
    ;;
  S)
    salt_suffix=${OPTARG}
    salt_position='suffix'
    salt_enc_suffix=$(echo -n "${OPTARG}" | openssl enc -A -base64)
    ;;
  V) is_email_verified='true' ;;
  v) set -x ;;
  h | ?) usage 0 ;;
  *) usage 1 ;;
  esac
done

declare password_field=''
declare custom_password_hash_field=''

if [[ ! -z "${password}" ]]; then
  declare -r salted_password="${salt_prefix}${password}${salt_suffix}"
  case ${algorithm} in
  bcrypt)
    readonly password_hash=$(htpasswd -bnBC ${bc_rounds} "" ${salted_password} | tr -d ':\n' | sed 's/$2y/$2b/')
    password_field=",\"password_hash\":\"${password_hash}\""
    ;;
  md5 | sha1 | sha256 | sha512)
    readonly password_hash=$(echo -n "${salted_password}" | openssl dgst -binary -${algorithm} | openssl enc -A -base64)
    custom_password_hash_field=$(
      cat <<EOL
, "custom_password_hash": {
    "algorithm": "${algorithm}",
    "hash": {
      "value": "${password_hash}",
      "encoding": "base64"
    },
    "salt": {
      "value": "${salt_enc_prefix}${salt_enc_suffix}",
      "encoding": "base64",
      "position": "${salt_position}"
    }
 }
EOL
    )
    ;;
  argon2)
    which >/dev/null argon2 || {
      echo >&2 "argon2 cli not installed"
      usage 1
    }
    declare -r password_hash=$(echo -n "${password}" | argon2 ${salt_prefix} -e)
    custom_password_hash_field=$(
      cat <<EOL
, "custom_password_hash": {
    "algorithm": "${algorithm}",
    "hash": "${password_hash}"
 }
EOL
    )
    ;;
  pbkdf2*)
    declare -r hashing_alg=$(echo "${algorithm}" | awk -F- '{print $2}')
    declare -r password_hash=$(./pbkdf2.sh -p "${password}" -a ${hashing_alg} -s "${salt_prefix}")
    custom_password_hash_field=$(
      cat <<EOL
, "custom_password_hash": {
    "algorithm": "pbkdf2",
    "hash": {
      "value": "${password_hash}",
      "encoding": "utf8"
    }
 }
EOL
    )
    ;;
  *)
    echo >&2 "Unsupported algorithm: $algorithm"
    usage 1
    ;;
  esac
fi

function singleUser() {
  local no=$1
  cat <<EOL
{ "email":"user${prefix}.${no}@${domain}","email_verified":${is_email_verified}${password_field}${custom_password_hash_field} }
EOL
}

#    "app_metadata": {
#        "roles": ["admin"],
#        "plan": "premium"
#    },
#    "user_metadata": {
#        "theme": "light"
#    }

echo '['
echo "" $(singleUser 1)

for i in $(seq 2 ${count}); do
  echo -n ','
  echo $(singleUser ${i})
done

echo ']'
