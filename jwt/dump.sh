#!/bin/bash

[[ $# -lt 1 ]] && jwt=$access_token || jwt=$1
echo $jwt | awk -F. '{print $2}' | base64 -d -w0 2>/dev/null | jq '.'
