Access Policy Steps
===================

A. M2M Client
-------------
1. build m2m 
```bash
cd ../clients
./create-client.sh -n "M2M for Grant Type" -t non_interactive
```

2. grant client_credentials from prev step against management API with below scopes 
```bash
./create-client-grants.sh -i H3l69Wu0pH81VQhk3kJjyXXXXXXX6h -m \
 -s create:access_policies,read:access_policies,delete:access_policies,update:access_policies
```

3. Figure out what's client_secret of this new client
```bash
./list-clients.sh 
```

B. Register
-----------
1. Use M2M client to get a management API access_token

```bash
cd ../login
export access_token=$(./client-credentials.sh -t tenant@region \
    -c bMZEeDKSzQkoDpJiKgZuhTHgRzZ4VFRE -x XXXX -m | jq -r .access_token)
```

2. register API Grant against a user with your API
```bash
cd ../api-policy
./create-api-policy.sh -c rs.client.id -a newapi -s do:something
```
