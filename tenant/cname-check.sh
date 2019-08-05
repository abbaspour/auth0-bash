#!/bin/bash

echo "" | openssl s_client -showcerts -connect $1:443 -servername $1  2>/dev/null | openssl x509 -text
