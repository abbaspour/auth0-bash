#!/bin/bash

# downloads x5c of tenant into a PEM file

set -eo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-e file] [-t tenant] [-d domain]
        -e file        # .env file location (default cwd)
        -t tenant      # Auth0 tenant@region
        -d domain      # Auth0 domain
        -c file        # Output cert file name
        -p file        # Output public key file name
        -D             # Dump certificate
        -h|?           # usage
        -v             # verbose

eg,
     $0 -t amin01@au
END
    exit $1
}

declare AUTH0_DOMAIN=''
declare cert_file=''
declare pubkey_file=''
declare opt_dump=''
declare opt_verbose=0


while getopts "e:t:d:f:Dhv?" opt
do
    case ${opt} in
        e) source ${OPTARG};;
        t) AUTH0_DOMAIN=`echo ${OPTARG}.auth0.com | tr '@' '.'`;;
        d) AUTH0_DOMAIN=${OPTARG};;
        f) cert_file=${OPTARG};;
        D) opt_dump=1;; 
        v) opt_verbose=1;; #set -x;;
        h|?) usage 0;;
        *) usage 1;;
    esac
done

[[ -z "${AUTH0_DOMAIN}" ]] && { echo >&2 "ERROR: AUTH0_DOMAIN undefined"; usage 1; }
[[ -z "${cert_file}" ]] && cert_file=${AUTH0_DOMAIN}-crt.pem
[[ -z "${pubkey_file}" ]] && pubkey_file=${AUTH0_DOMAIN}-pub.pem

declare -r jwks_uri=`curl -s https://${AUTH0_DOMAIN}/.well-known/openid-configuration | jq -r '.jwks_uri'`
declare -r x5c=`curl -s ${jwks_uri} | jq -r '.keys [0] .x5c [0]'`


echo '-----BEGIN CERTIFICATE-----'  > ${cert_file}
echo $x5c | fold -w64 >> ${cert_file}
echo '-----END CERTIFICATE-----' >> ${cert_file}

[[ ${opt_dump} ]] && openssl x509 -in ${cert_file} -text -noout

openssl x509 -in ${cert_file} -pubkey -noout > ${pubkey_file}

echo "cert_file: ${cert_file}"
echo "pubkey_file: ${pubkey_file}"
