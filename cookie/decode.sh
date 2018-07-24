#!/bin/bash

urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

urldecode $1 | awk -F[:.] '{print $2}'
