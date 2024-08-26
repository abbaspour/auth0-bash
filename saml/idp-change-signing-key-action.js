/**
 * Handler that will be called during the execution of a PostLogin flow.
 *
 * @param {Event} event - Details about the user and the context in which they are logging in.
 * @param {PostLoginAPI} api - Interface whose methods can be used to change the behavior of the login.
 */
exports.onExecutePostLogin = async (event, api) => {

    // replace with the ID of the application that has the SAML Web App Addon enabled
    // for which you want to change the signing key pair.
    const samlIdpClientId = "${samlIdpClientId}";

    const signingCert = "${signingCert}";
    const signingKey = "${signingKey}";

    // only do this for the specific client ID.  If you have multiple IdPs that require
    // custom certificates, you will have an "if" statement for each one.
    if (event.client.client_id === samlIdpClientId) {

        // provide your own private key and certificate here
        // see https://auth0.com/docs/authenticate/protocols/saml/saml-sso-integrations/work-with-certificates-and-keys-as-strings
        // for formatting instructions basically you start with a PEM format certificate and
        // replace the line endings with "\n"

        console.log(`signingCert: ${signingCert}`);

        api.samlResponse.setCert(signingCert);
        api.samlResponse.setKey(signingKey);

    }
};