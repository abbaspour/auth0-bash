realm=master
client=auth0
host=localhost:8080

open http://${host}/auth/realms/${realm}/protocol/saml/clients/${client}
