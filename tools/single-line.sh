#!/bin/bash
sed 's/$/\\n/' $1 | tr -d '\n'
echo
