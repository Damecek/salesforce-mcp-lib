/**
 * Handles the MCP {@code ping} JSON-RPC request.
 *
 * <p>Returns an empty result object, confirming that the server is
 * alive and responsive. No parameters are expected or consumed.</p>
 */
public inherited sharing class McpPingHandler extends JsonRpcMethodHandler {

    /**
     * Constructs the ping handler.
     */
    public McpPingHandler() {
        super('ping', null, null);
    }

    /**
     * Returns an empty success response to acknowledge the ping.
     *
     * @param context The invocation context for this request.
     * @return A successful {@link JsonRpcResponse} with an empty result map.
     */
    public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
        return JsonRpcResponse.success(context.requestId, new Map<String, Object>());
    }
}
