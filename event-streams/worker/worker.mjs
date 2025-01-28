export default {
    async fetch(request, env, ctx) {
        try {
            // Log basic details of the request
            console.log("Request URL:", request.url);
            console.log("Request Method:", request.method);
            console.log("Request Headers:", JSON.stringify([...request.headers]));

            // Clone the request to read the body safely
            const clonedRequest = request.clone();

            // Try to parse the request body
            let body = null;
            if (request.headers.get("content-type")?.includes("application/json")) {
                body = await clonedRequest.json(); // Parse JSON body if content-type is application/json
            } else {
                body = await clonedRequest.text(); // Otherwise, just treat it as plain text
            }
            console.log("Request Body:", body);

            // Respond back with a JSON object that shows request details
            return new Response({}, {status: 200});
        } catch (error) {
            console.error("Error logging request:", error);
            return new Response("Internal Server Error", {status: 500});
        }
    },
};
