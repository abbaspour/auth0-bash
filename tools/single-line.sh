#!/bin/bash
sed 's|\\|\\\\|g;s/$/\\n/g' $1 | tr -d '\n'
echo
