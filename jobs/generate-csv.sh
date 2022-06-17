#!/usr/bin/env bash

set -eu

function usage() {
    cat <<END >&2
USAGE: $0 [-n records] [-d accounts] [-a algorithm] [-p password] [-s salt] [-E]
        -n records   # number of records to generate (default is 1)
        -d accounts  # number of accounts per customer_id (default is 1)
        -a algorithm # hashing algorithm: md5 or sha1 (default is md5)
        -p password  # password (default is random)
        -s salt      # hashing salt (default is no salt)
        -E           # generate random email (default is no email)
        -H           # no print header
        -S           # random salt
        -o file      # output file name
        -h|?         # usage
        -v           # verbose

eg,
     $0 -n 1 -d 2 -o users.json
END
    exit $1
}


function random_string() {
  cat /dev/urandom | tr -dc _A-Z-a-z-0-9 | head -c${1:-8}
}

declare -i no_records=1
declare -i no_accounts=1
declare algorithm='md5'
declare -i random_email=0
declare -i random_salt=0
declare -i header=1
declare -i opt_verbose=0
declare fix_password=''
declare fix_salt=''

while getopts "n:d:a:p:s:o:SEHhv?" opt
do
    case ${opt} in
        n) no_records=${OPTARG};;
        d) no_accounts=${OPTARG};;
        a) algorithm=${OPTARG};;
        p) fix_password=${OPTARG};;
        s) fix_salt=${OPTARG};;
        o) exec > ${OPTARG};;
        E) random_email=1;;
        S) random_salt=1;;
        H) header=0;;
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done


[[ ${header} -ne 0 ]] && echo "# customer_id, account_no, email, plain_password, algorithm, salt, hash"

for r in `seq 1 ${no_records}`; do
  declare customer_id="c_$(echo $RANDOM)"
  for a in `seq 1 ${no_accounts}`; do
    declare account_no="a_$(echo $RANDOM)"
    declare email=''
    [[ ${random_email} -eq 1 ]] && email="somebody+$(echo $RANDOM)@gmail.com"
    declare password=$(random_string 12)
    [[ -n ${fix_password} ]] && password="${fix_password}"
    declare salt="${fix_salt}"
    [[ ${random_salt} -eq 1 ]] && salt=$(random_string 4)
    declare salt_b64=$(echo -n "${salt}" | openssl enc -A -base64)
    declare salted_password="$salt$password"
    declare password_hash=$(echo -n "${salted_password}" | openssl dgst -binary -${algorithm} | openssl enc -A -base64)
    echo "${customer_id},${account_no},${email},${password},${algorithm},${salt_b64},${password_hash}"
  done
done
