/**
 * @description Invocation context passed to MCP executors.
 */
public inherited sharing class McpRequestContext {
    /** @description JSON-RPC method name, for diagnostics and telemetry. */
    public String methodName;
    /** @description Typed JSON-RPC request identifier wrapper. */
    public JsonRpcIdValue requestId;
    /** @description Raw JSON-RPC request envelope. */
    public Map<String, Object> rawRequest;
    /** @description Zero-based index for batch requests. */
    public Integer batchIndex;

    /**
     * @description Creates MCP context from JSON-RPC invocation context.
     * @param source JSON-RPC invocation context.
     * @return New MCP request context.
     */
    public static McpRequestContext fromJsonRpc(JsonRpcInvocationContext source) {
        McpRequestContext context = new McpRequestContext();
        if (source == null) {
            return context;
        }
        context.methodName = source.methodName;
        context.requestId = source.requestId;
        context.rawRequest = source.rawRequest;
        context.batchIndex = source.batchIndex;
        return context;
    }
}
