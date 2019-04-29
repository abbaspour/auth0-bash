Tenant Creation Steps
=====================

*Note*: These steps only work in RTA setup.

A. M2M Client in RTA
--------------------
1. Get `access_token` from RTA tenant.

```bash
export access_token='...'
```

2. build m2m in RTA tenant
```bash
cd ../clients
./create-client.sh -n "M2M for Tenant Creation" -t non_interactive
```

3. grant client_credentials from prev step against management API with below scopes 
```bash
./create-client-grants.sh -i client_id_a2 -m \
 -s create:tenants,update:tenants,delete:tenants,read:tenants
```

4. Figure out what's client_secret of this new client
```bash
./list-clients.sh 
```

B. Access Token for Tenant Creation
-----------------------------------
1. Access Token
```bash
cd ../login
export access_token=$(./client-credentials.sh \
    -d demo-rta.appliance-trial.com -m \
    -c m2m_client_id_a2 -x m2m_client_secret_a2 | jq -r .access_token)
```

2. Creat Tenant
```bash
cd ../tenant
./create-tenant.sh -n test-tenant01
```

C. Add Clients to new Tenant
----------------------------
1. Make sure DNS is setup for your new tenant

```
fgrep demo-rta.appliance-trial.com /etc/hosts | awk '{print $1}'

sudo vi /etc/hosts
w.x.y.z test-tenant01.appliance-trial.com
```

2. Access Token

```bash
cd ../login
export access_token=$(./client-credentials.sh \
    -d test-tenant01.appliance-trial.com -m \
    -c m2m_client_id_b2 -x m2m_client_secret_b2 | jq -r .access_token)
```

3. Create Client
```bash
cd ../clients
./create-client.sh -n "Tenant Lifecycle" -t non_interactive
```

4.  grant client_credentials from prev step against management API with below scopes
 
```bash
./create-client-grants.sh -i client_id_c3 -m \
 -s create:tenant_invitations,read:tenant_invitations,delete:tenant_invitations,read:owners,delete:owners
```

D. Invite Admins
----------------

1. Access Token

```bash
cd ../login
export access_token=$(./client-credentials.sh \
    -d test-tenant01.appliance-trial.com -m \
    -c m2m_client_id_c3 -x m2m_client_secret_c3 | jq -r .access_token)
```

2. Set SMTP under https://demo-manage.appliance-trial.com/configuration#/settings

3. Invite Admins
```bash
cd ../tenant
./invite-admin.sh -m admin@example.com
```

4. Copy the link from D3 to browser or from mailbox and accept

5. List admins
```bash
./list-admins.sh
```
