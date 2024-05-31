export default {
    async fetch(request, env, ctx) {
        return handleRequest(request);
    }
};

async function handleRequest(request) {
    if (request.method === 'POST') {
        // Parse the form data
        const formData = await request.formData();
        const SAMLResponse = formData.get('SAMLResponse');
        const RelayState = formData.get('RelayState');

        if (!SAMLResponse) {
            return new Response('SAMLResponse parameter is missing.', { status: 400 });
        }

        // Generate HTML form for redirection
        const redirectUrl = 'https://abbaspour.auth0.com/login/callback?connection=Amin-JP-SAML'; // Replace with your predefined URL
        const html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <title>Redirecting...</title>
      </head>
      <body onload="document.forms[0].submit()">
        <form method="POST" action="${redirectUrl}">
          <input type="hidden" name="SAMLResponse" value="${SAMLResponse}">
          ${RelayState ? `<input type="hidden" name="RelayState" value="${RelayState}">` : ''}
        </form>
        <p>Redirecting...</p>
      </body>
      </html>
    `;

        return new Response(html, {
            headers: { 'Content-Type': 'text/html' },
        });
    } else {
        return new Response('Method not allowed', { status: 405 });
    }
}
