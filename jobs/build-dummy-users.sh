#!/bin/bash

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-c number]
        -c number   # number of dummy users
        -p prefix   # prefix

eg,
     $0 -c 10
END
    exit $1
}

declare count=1
declare prefix='.'

while getopts "e:a:c:p:hv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        a) access_token=${OPTARG};;
        c) count=${OPTARG};;
        p) prefix=${OPTARG};;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

function singleUser() {
    local no=$1
    cat <<EOL
{
    "email": "user${prefix}.${no}@contoso.com",
    "email_verified": false,
    "app_metadata": {
        "roles": ["admin"],
        "plan": "premium"
    },
    "user_metadata": {
        "theme": "light"
    }
}    
EOL
}

echo '['
echo $(singleUser 1)

for i in `seq 2 ${count}`; do
    echo ','
    echo $(singleUser ${i}) 
done

echo ']'
