/**
 * Handles the MCP {@code tools/call} JSON-RPC request.
 *
 * <p>Dispatches tool invocations by looking up the requested tool by name,
 * validating the supplied arguments, and executing the tool logic. Tool-level
 * errors (validation failures, runtime exceptions) are returned as successful
 * JSON-RPC responses with {@code isError: true} per the MCP specification --
 * only protocol-level failures produce JSON-RPC error responses.</p>
 */
public class McpToolsCallHandler extends JsonRpcMethodHandler {

    private final Map<String, McpToolDefinition> toolsByName;

    /**
     * Constructs the tools/call handler with the server's registered tools.
     *
     * <p>Tools are indexed by name in a map for O(1) lookup at invocation time.</p>
     *
     * @param tools The list of registered tool definitions.
     */
    public McpToolsCallHandler(List<McpToolDefinition> tools) {
        super('tools/call', null, null);
        this.toolsByName = new Map<String, McpToolDefinition>();
        for (McpToolDefinition tool : tools) {
            this.toolsByName.put(tool.name, tool);
        }
    }

    /**
     * Dispatches the tool call: validates the request, looks up the tool,
     * validates arguments, executes the tool, and returns the result.
     *
     * <p>Tool-level errors are wrapped in a successful JSON-RPC response
     * with {@code isError: true}. Only missing or malformed protocol-level
     * fields produce JSON-RPC error responses.</p>
     *
     * @param context The invocation context for this request.
     * @return A {@link JsonRpcResponse} containing the tool result or an error.
     */
    public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
        Map<String, Object> rawRequest = context.rawRequest;
        Map<String, Object> params = (Map<String, Object>) rawRequest.get('params');

        if (params == null) {
            return JsonRpcResponse.failure(
                context.requestId,
                JsonRpcError.invalidParams('Missing params')
            );
        }

        String toolName = (String) params.get('name');
        if (toolName == null) {
            return JsonRpcResponse.failure(
                context.requestId,
                JsonRpcError.invalidParams('Missing required field: name')
            );
        }

        McpToolDefinition tool = this.toolsByName.get(toolName);
        if (tool == null) {
            return JsonRpcResponse.failure(
                context.requestId,
                JsonRpcError.invalidParams('Unknown tool: ' + toolName)
            );
        }

        try {
            Map<String, Object> arguments = (Map<String, Object>) params.get('arguments');
            if (arguments == null) {
                arguments = new Map<String, Object>();
            }

            tool.validate(arguments);
            McpToolResult result = tool.execute(arguments);

            return JsonRpcResponse.success(context.requestId, result);
        } catch (McpInvalidParamsException e) {
            McpToolResult errorResult = new McpToolResult();
            errorResult.isError = true;
            errorResult.content = new List<McpTextContent>{
                new McpTextContent(e.getMessage())
            };
            return JsonRpcResponse.success(context.requestId, errorResult);
        } catch (Exception e) {
            McpToolResult errorResult = new McpToolResult();
            errorResult.isError = true;
            errorResult.content = new List<McpTextContent>{
                new McpTextContent(e.getMessage())
            };
            return JsonRpcResponse.success(context.requestId, errorResult);
        }
    }
}
