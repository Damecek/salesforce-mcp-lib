/**
 * @description Contract for executing a registered MCP tool.
 */
public interface McpToolExecutor {
    /**
     * @description Executes tool business logic.
     * @param arguments Untyped arguments map from tools/call.
     * @param context Invocation context for this request.
     * @return Arbitrary result payload returned to MCP client.
     */
    Object execute(Map<String, Object> arguments, McpRequestContext context);
}
