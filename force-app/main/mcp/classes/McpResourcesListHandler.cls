/**
 * Handles the MCP {@code resources/list} JSON-RPC request.
 *
 * <p>Returns the complete catalog of resources registered with the server,
 * including each resource's URI, name, description, and MIME type. The
 * response format conforms to the MCP {@code resources/list} result
 * specification.</p>
 */
public class McpResourcesListHandler extends JsonRpcMethodHandler {

    private final List<McpResourceDefinition> resources;

    /**
     * Constructs the resources/list handler with the server's registered resources.
     *
     * @param resources The list of registered resource definitions.
     */
    public McpResourcesListHandler(List<McpResourceDefinition> resources) {
        super('resources/list', null, null);
        this.resources = resources;
    }

    /**
     * Builds and returns the resource catalog for the {@code resources/list} response.
     *
     * <p>Each resource entry includes its URI and name. Description and MIME type
     * are included when present.</p>
     *
     * @param context The invocation context for this request.
     * @return A successful {@link JsonRpcResponse} containing the resource list.
     */
    public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
        List<Map<String, Object>> resourceEntries = new List<Map<String, Object>>();

        for (McpResourceDefinition resource : this.resources) {
            Map<String, Object> entry = new Map<String, Object>();
            entry.put('uri', resource.uri);
            entry.put('name', resource.name);
            if (resource.description != null) {
                entry.put('description', resource.description);
            }
            if (resource.mimeType != null) {
                entry.put('mimeType', resource.mimeType);
            }
            resourceEntries.add(entry);
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('resources', resourceEntries);

        return JsonRpcResponse.success(context.requestId, result);
    }
}
