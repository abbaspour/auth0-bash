#!/bin/bash

##########################################################################################
# Author: Auth0
# Date: 2022-06-12
# License: MIT (https://github.com/auth0/auth0-bash/blob/main/LICENSE)
##########################################################################################

set -ueo pipefail

function usage() {
    cat <<END >&2
USAGE: $0 [-u username] [-l] [-v|-h]
        -u username    # username
        -l             # just list
        -p page        # page (default 1) 
        -h|?           # usage
        -v             # verbose

eg,
     $0 -u abbaspour
END
    exit $1
}

declare opt_verbose=0
declare username=''
declare page=1

declare cmd='xargs -L1 git clone'

while getopts "u:p:lhv?" opt; do
    case ${opt} in
    u) username=${OPTARG} ;;
    p) page=${OPTARG} ;;
    l) cmd='tee' ;;
    v) opt_verbose=1 ;; #set -x;;
    h | ?) usage 0 ;;
    *) usage 1 ;;
    esac
done

[[ -z "${username}" ]] && {
    echo >&2 "ERROR: username undefined"
    usage 1
}

curl -s "https://api.github.com/users/${username}/repos?page=${page}&per_page=100" | grep -e 'git_url*' | cut -d \" -f 4 | ${cmd}
