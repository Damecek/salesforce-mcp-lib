/**
 * Handles the MCP {@code resources/read} JSON-RPC request.
 *
 * <p>Dispatches resource reads by looking up the requested resource by URI
 * and returning its content. Unknown URIs produce a JSON-RPC error response
 * with code {@code -32602} (invalid params).</p>
 */
public inherited sharing class McpResourcesReadHandler extends JsonRpcMethodHandler {

    private final Map<String, McpResourceDefinition> resourcesByUri;

    /**
     * Constructs the resources/read handler with the server's registered resources.
     *
     * <p>Resources are indexed by URI in a map for O(1) lookup at invocation time.</p>
     *
     * @param resources The list of registered resource definitions.
     */
    public McpResourcesReadHandler(List<McpResourceDefinition> resources) {
        super('resources/read', null, null);
        this.resourcesByUri = new Map<String, McpResourceDefinition>();
        for (McpResourceDefinition resource : resources) {
            this.resourcesByUri.put(resource.uri, resource);
        }
    }

    /**
     * Dispatches the resource read: validates the request, looks up the resource
     * by URI, reads its content, and returns the result.
     *
     * <p>Missing or unknown URIs produce a JSON-RPC error response with code
     * {@code -32602}.</p>
     *
     * @param context The invocation context for this request.
     * @return A {@link JsonRpcResponse} containing the resource contents or an error.
     */
    public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
        Map<String, Object> params = (Map<String, Object>) context.rawRequest.get('params');

        if (params == null) {
            return JsonRpcResponse.failure(
                context.requestId,
                JsonRpcError.invalidParams('Missing params')
            );
        }

        String uri = (String) params.get('uri');
        if (uri == null) {
            return JsonRpcResponse.failure(
                context.requestId,
                JsonRpcError.invalidParams('Missing required field: uri')
            );
        }

        McpResourceDefinition resource = this.resourcesByUri.get(uri);
        if (resource == null) {
            return JsonRpcResponse.failure(
                context.requestId,
                JsonRpcError.invalidParams('Unknown resource: ' + uri)
            );
        }

        McpResourceResult readResult = resource.read();

        List<Map<String, Object>> contentsWire = new List<Map<String, Object>>();
        if (readResult.contents != null) {
            for (McpResourceContentItem item : readResult.contents) {
                Map<String, Object> itemMap = new Map<String, Object>();
                itemMap.put('uri', item.uri);
                if (item.mimeType != null) {
                    itemMap.put('mimeType', item.mimeType);
                }
                if (item.text != null) {
                    itemMap.put('text', item.text);
                }
                if (item.blobData != null) {
                    itemMap.put('blob', item.blobData);
                }
                contentsWire.add(itemMap);
            }
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('contents', contentsWire);

        return JsonRpcResponse.success(context.requestId, result);
    }
}
