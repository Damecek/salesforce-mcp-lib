/**
 * Wraps Salesforce {@code RestRequest} / {@code RestResponse} for the
 * MCP framework.
 *
 * <p>Provides a thin abstraction over the platform REST context so that
 * the core request-processing pipeline does not depend directly on
 * {@code RestContext} statics.</p>
 */
public inherited sharing class McpHttpTransport {

    private final RestRequest req;
    private final RestResponse res;

    /**
     * Creates a new transport wrapping the given platform request and response.
     *
     * @param req the Salesforce {@code RestRequest}
     * @param res the Salesforce {@code RestResponse}
     */
    public McpHttpTransport(RestRequest req, RestResponse res) {
        this.req = req;
        this.res = res;
    }

    /**
     * Returns the raw JSON body from the incoming REST request.
     *
     * @return the request body as a {@code String}
     */
    public String getRequestBody() {
        return req.requestBody.toString();
    }

    /**
     * Writes a JSON-RPC response to the outgoing REST response.
     *
     * <p>Sets the response body and adds the {@code Content-Type: application/json}
     * header.</p>
     *
     * @param json the serialized JSON-RPC response
     */
    public void setResponseBody(String json) {
        res.responseBody = Blob.valueOf(json);
        res.addHeader('Content-Type', 'application/json');
    }
}
