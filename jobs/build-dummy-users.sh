#!/bin/bash

set -eo pipefail

declare -i bc_rounds=10
declare domain='contoso.com'
declare -r OPENSSL_1_1_1='/usr/local/Cellar/openssl@1.1/1.1.1d/bin/openssl'

function usage() {
    cat <<END >&2
USAGE: $0 [-c number]
        -c number   # number of dummy users
        -p prefix   # prefix
        -x password # password
        -s salt     # password salt prefix
        -S salt     # password salt suffix
        -a name     # password hash algorithm; bcrypt (default), md4, md5, ldap, sha1, sha256, sha512, argon2, pbkdf2
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

while getopts "e:a:c:p:d:x:r:a:s:S:Vhv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) algorithm=${OPTARG};;
        c) count=${OPTARG};;
        p) prefix=${OPTARG};;
        x) password=${OPTARG};;
        d) domain=${OPTARG};;
        r) round=${OPTARG};;
        s) salt_prefix=${OPTARG};;
        S) salt_suffix=${OPTARG};;
        V) is_email_verified='true';;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

declare password_field=''
declare custom_password_hash_field=''

if [[ ! -z "${password}" ]]; then
  declare -r salted_password="${salt_prefix}${password}${salt_suffix}"
  case ${algorithm} in
    bcrypt)
      declare -r password_hash=$(htpasswd -bnBC ${bc_rounds} "" ${salted_password} | tr -d ':\n' | sed 's/$2y/$2b/')
      password_field=",\"password_hash\":\"${password_hash}\"";;
    md5|sha1|sha256|sha512)
      declare -r password_hash=$(echo -n "${salted_password}" | openssl dgst -binary -${algorithm} | openssl enc -A -base64)
      custom_password_hash_field=$(cat <<EOL
, "custom_password_hash": {
    "algorithm": "${algorithm}",
    "hash": "${password_hash}",
    "encoding": "base64",
    "salt_prefix": "${salt_prefix}",
    "salt_suffix": "${salt_suffix}"
 }
EOL
);;
    argon2)
      which >/dev/null argon2 || { echo >&2 "argon2 cli not installed"; usage 1; }
      declare -r password_hash=$(echo -n "${password}" | argon2 ${salt_prefix} -e)
      custom_password_hash_field=$(cat <<EOL
, "custom_password_hash": {
    "algorithm": "${algorithm}",
    "hash": "${password_hash}"
 }
EOL
);;
    pbkdf2)
      echo >&2 "WIP algorithm: $algorithm"; usage 1;;
      declare -r hex_salt=$(openssl rand -hex 16)
      #declare -r hex_salt=$(openssl rand -base64 4)
      declare -ri itr=1000
      declare -ri len=64
      #declare -r hash=$(echo -n "${password}" | ${OPENSSL_1_1_1} enc -aes-256-cbc -md sha1 -pbkdf2 -iter ${itr} -pass stdin -S ${hex_salt} -a -A)
      declare -r hash=$(node -e "const crypto = require('crypto'); console.log(crypto.pbkdf2Sync('${password}', Buffer.from('${hex_salt}', 'hex'), ${itr}, ${len}, 'sha1').toString('base64'));" )
      declare -r password_hash=$(echo "\$pbkdf2-sha1\$i=${itr},l=${len}\$${hex_salt}\$${hash}")
      custom_password_hash_field=$(cat <<EOL
, "custom_password_hash": {
    "algorithm": "pbkdf2",
    "hash": "${password_hash}"
 }
EOL
);;
    *)
      echo >&2 "Unsupported algorithm: $algorithm"; usage 1;;
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

for i in `seq 2 ${count}`; do
    echo -n ','
    echo $(singleUser ${i})
done

echo ']'
