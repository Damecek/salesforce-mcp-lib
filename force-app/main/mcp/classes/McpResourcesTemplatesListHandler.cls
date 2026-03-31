/**
 * Handles the MCP {@code resources/templates/list} JSON-RPC request.
 *
 * <p>Returns the complete catalog of resource templates registered with
 * the server, including each template's URI template, name, description,
 * and MIME type. The response format conforms to the MCP
 * {@code resources/templates/list} result specification.</p>
 */
public class McpResourcesTemplatesListHandler extends JsonRpcMethodHandler {

    private final List<McpResourceTemplateDefinition> templates;

    /**
     * Constructs the resources/templates/list handler with the server's
     * registered resource templates.
     *
     * @param templates The list of registered resource template definitions.
     */
    public McpResourcesTemplatesListHandler(List<McpResourceTemplateDefinition> templates) {
        super('resources/templates/list', null, null);
        this.templates = templates;
    }

    /**
     * Builds and returns the resource template catalog for the
     * {@code resources/templates/list} response.
     *
     * <p>Each template entry includes its URI template and name. Description
     * and MIME type are included when present.</p>
     *
     * @param context The invocation context for this request.
     * @return A successful {@link JsonRpcResponse} containing the template list.
     */
    public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
        List<Map<String, Object>> templateEntries = new List<Map<String, Object>>();

        for (McpResourceTemplateDefinition template : this.templates) {
            Map<String, Object> entry = new Map<String, Object>();
            entry.put('uriTemplate', template.uriTemplate);
            entry.put('name', template.name);
            if (template.description != null) {
                entry.put('description', template.description);
            }
            if (template.mimeType != null) {
                entry.put('mimeType', template.mimeType);
            }
            templateEntries.add(entry);
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('resourceTemplates', templateEntries);

        return JsonRpcResponse.success(context.requestId, result);
    }
}
