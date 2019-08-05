#!/bin/bash

set -eo pipefail

declare -ri bc_rounds=10
declare domain='contoso.com'

function usage() {
    cat <<END >&2
USAGE: $0 [-c number]
        -c number   # number of dummy users
        -p prefix   # prefix
        -x password # password
        -V          # set email_verified to true
        -d domain   # domain. default is ${domain}

eg,
     $0 -c 10
END
    exit $1
}

declare count=1
declare prefix=''
declare password_field=''
declare is_email_verified='false'

while getopts "e:a:c:p:d:x:Vhv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        c) count=${OPTARG};;
        p) prefix=${OPTARG};;
        x) declare -r password_hash=$(htpasswd -bnBC ${bc_rounds} "" ${OPTARG} | tr -d ':\n' | sed 's/$2y/$2b/'); password_field=",\"password_hash\":\"${password_hash}\"";;
        d) domain=${OPTARG};;
        V) is_email_verified='true';;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

function singleUser() {
    local no=$1
    cat <<EOL
{ "email":"user${prefix}.${no}@${domain}","email_verified":${is_email_verified}${password_field} }    
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
