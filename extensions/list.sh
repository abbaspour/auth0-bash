#!/bin/bash
curl -sL https://cdn.auth0.com/extensions/extensions.json | jq -r '.[] | "\(.name) \t \(.version)"'
