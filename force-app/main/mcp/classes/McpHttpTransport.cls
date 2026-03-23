/**
 * @description Reusable Apex REST transport adapter for MCP JSON-RPC requests.
 * @example
 * {@code
 * @RestResource(urlMapping='/mcp/*')
 * global with sharing class MyEndpoint {
 *   @HttpPost
 *   global static void handlePost() {
 *     McpServer server = new MyServerBuilder().build();
 *     McpHttpTransport.handlePost(server);
 *   }
 * }
 * }
 */
public inherited sharing class McpHttpTransport {
    /**
     * @description Handles current RestContext POST request with default options.
     * @param server MCP server instance.
     */
    public static void handlePost(McpServer server) {
        handlePost(server, null);
    }

    /**
     * @description Handles current RestContext POST request with explicit JSON-RPC options.
     * @param server MCP server instance.
     * @param options Runtime options; when null defaults are used.
     */
    public static void handlePost(McpServer server, JsonRpcServiceRuntimeOptions options) {
        if (server == null) {
            throw new McpInvalidParamsException('McpServer is required.');
        }

        RestRequest request = RestContext.request;
        RestResponse response = RestContext.response;

        if (request == null || response == null) {
            throw new McpInvalidParamsException('RestContext request and response must be available.');
        }

        String requestJson = request.requestBody == null ? null : request.requestBody.toString();

        JsonRpcExecutionResult executionResult = server.execute(requestJson, options);

        response.addHeader('Content-Type', 'application/json');
        if (!executionResult.hasResponse) {
            response.statusCode = 204;
            response.responseBody = Blob.valueOf('');
            return;
        }

        response.statusCode = 200;
        response.responseBody = Blob.valueOf(executionResult.toJson());
    }
}
