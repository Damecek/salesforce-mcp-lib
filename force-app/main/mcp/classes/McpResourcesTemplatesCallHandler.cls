/**
 * Handles the MCP {@code resources/templates/call} JSON-RPC request.
 *
 * <p>Dispatches templated resource reads by looking up the requested
 * resource template by its URI template string, extracting the supplied
 * arguments, and returning the content. Unknown URI templates produce a
 * JSON-RPC error response with code {@code -32602} (invalid params).</p>
 */
public inherited sharing class McpResourcesTemplatesCallHandler extends JsonRpcMethodHandler {

    private final Map<String, McpResourceTemplateDefinition> templatesByUri;

    /**
     * Constructs the resources/templates/call handler with the server's
     * registered resource templates.
     *
     * <p>Templates are indexed by URI template in a map for O(1) lookup
     * at invocation time.</p>
     *
     * @param templates The list of registered resource template definitions.
     */
    public McpResourcesTemplatesCallHandler(List<McpResourceTemplateDefinition> templates) {
        super('resources/templates/call', null, null);
        this.templatesByUri = new Map<String, McpResourceTemplateDefinition>();
        for (McpResourceTemplateDefinition template : templates) {
            this.templatesByUri.put(template.uriTemplate, template);
        }
    }

    /**
     * Dispatches the templated resource read: validates the request, looks up
     * the template by URI, extracts arguments, reads the content, and returns
     * the result.
     *
     * <p>Missing or unknown URI templates produce a JSON-RPC error response
     * with code {@code -32602}.</p>
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

        McpResourceTemplateDefinition template = this.templatesByUri.get(uri);
        if (template == null) {
            return JsonRpcResponse.failure(
                context.requestId,
                JsonRpcError.invalidParams('Unknown resource template: ' + uri)
            );
        }

        Map<String, String> arguments = new Map<String, String>();
        Object rawArguments = params.get('arguments');
        if (rawArguments != null) {
            Map<String, Object> rawArgs = (Map<String, Object>) rawArguments;
            for (String key : rawArgs.keySet()) {
                arguments.put(key, String.valueOf(rawArgs.get(key)));
            }
        }

        McpResourceResult readResult = template.read(arguments);

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
