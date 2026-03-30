/**
 * Handles the MCP {@code tools/list} JSON-RPC request.
 *
 * <p>Returns the complete catalog of tools registered with the server,
 * including each tool's name, description, input schema, and optional
 * annotations. The response format conforms to the MCP {@code tools/list}
 * result specification.</p>
 */
public class McpToolsListHandler extends JsonRpcMethodHandler {

    private final List<McpToolDefinition> tools;

    /**
     * Constructs the tools/list handler with the server's registered tools.
     *
     * @param tools The list of registered tool definitions.
     */
    public McpToolsListHandler(List<McpToolDefinition> tools) {
        super('tools/list', null, null);
        this.tools = tools;
    }

    /**
     * Builds and returns the tool catalog for the {@code tools/list} response.
     *
     * <p>Each tool entry includes its name, description, and input schema.
     * When a tool has annotations, those are included as well.</p>
     *
     * @param context The invocation context for this request.
     * @return A successful {@link JsonRpcResponse} containing the tool list.
     */
    public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
        List<Map<String, Object>> toolEntries = new List<Map<String, Object>>();

        for (McpToolDefinition tool : this.tools) {
            Map<String, Object> entry = new Map<String, Object>();
            entry.put('name', tool.name);
            entry.put('description', tool.description);
            entry.put('inputSchema', tool.inputSchema());

            if (tool.annotations != null) {
                Map<String, Object> annotationsMap = new Map<String, Object>();
                if (tool.annotations.readOnlyHint != null) {
                    annotationsMap.put('readOnlyHint', tool.annotations.readOnlyHint);
                }
                if (tool.annotations.destructiveHint != null) {
                    annotationsMap.put('destructiveHint', tool.annotations.destructiveHint);
                }
                if (tool.annotations.idempotentHint != null) {
                    annotationsMap.put('idempotentHint', tool.annotations.idempotentHint);
                }
                if (tool.annotations.openWorldHint != null) {
                    annotationsMap.put('openWorldHint', tool.annotations.openWorldHint);
                }
                entry.put('annotations', annotationsMap);
            }

            toolEntries.add(entry);
        }

        Map<String, Object> result = new Map<String, Object>();
        result.put('tools', toolEntries);

        return JsonRpcResponse.success(context.requestId, result);
    }
}
