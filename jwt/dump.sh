#!/bin/bash

echo $1 | awk -F. '{print $2}' | base64 -d -w0 2>/dev/null | jq '.'
