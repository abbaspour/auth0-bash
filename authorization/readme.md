B. M2M Client
-------------
1. build m2m 
```bash
cd ../clients
./create-client.sh -n "M2M for Authorization" -t non_interactive
```

2. grant client_credentials from prev step against management API with below scopes 
```bash
./create-client-grants.sh -i IIIIIIII -m \
 -s create:roles,delete:roles,read:roles,update:roles
```

3. Figure out what's client_secret of this new client
```bash
./list-clients.sh | grep -A2 IIIIII
```


4. Use M2M client to get a management API access_token

```bash
cd ../login
export access_token=$(./client-credentials.sh -t tenant@region \
    -c IIIII -x XXXX -m | jq -r .access_token)
```

