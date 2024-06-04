// Define the URL to redirect to
const redirectURL = "https://amin.jp.auth0.com/samlp/xxxx";

// Azure / Entra ID
//const redirectURL = "https://login.microsoftonline.com/xxx/saml2";

export default {
    async fetch(request, env, ctx) {
        return handleRequest(request);
    }
};

// Define the function to handle incoming requests
async function handleRequest(request) {

    // Parse the request URL
    const url = new URL(request.url);

    // Check if the request method is POST
    if (request.method === "POST") {
        // Parse the POST body
        const formData = await request.formData();

        // Get SAMLRequest and RelayState from the POST body
        const samlRequest = formData.get("SAMLRequest");
        const relayState = formData.get("RelayState");

        /* uncomment for Redirect binding
        // Redirect with query parameters
        return Response.redirect(
            `${redirectURL}?SAMLRequest=${encodeURIComponent(
                samlRequest
            )}&RelayState=${encodeURIComponent(relayState || "")}`,
            302
        );
        */

        const html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <title>Redirecting...</title>
      </head>
      <body onload="document.forms[0].submit()">
        <form method="POST" action="${redirectURL}">
          <input type="hidden" name="SAMLRequest" value="${samlRequest}">
          ${relayState ? `<input type="hidden" name="RelayState" value="${relayState}">` : ''}
        </form>
        <p>Redirecting...</p>
      </body>
      </html>
    `;

        return new Response(html, {
            headers: { 'Content-Type': 'text/html' },
        });

    } else {
        const queryParams = Object.fromEntries(url.searchParams.entries());

        // Get SAMLRequest and RelayState from the query string
        const samlRequest = queryParams["SAMLRequest"];
        const relayState = queryParams["RelayState"];

        // Redirect with query parameters
        return Response.redirect(
            `${redirectURL}?SAMLRequest=${encodeURIComponent(
                samlRequest || ""
            )}&RelayState=${encodeURIComponent(relayState || "")}`,
            302
        );
    }
}