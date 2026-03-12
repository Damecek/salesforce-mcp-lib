/**
 * @description Contract for executing a registered MCP tool.
 */
public interface McpToolExecutor {
    /**
     * @description Executes tool business logic.
     * @param arguments Typed arguments DTO declared by the tool definition.
     * @param context Invocation context for this request.
     * @return Typed tool result payload returned to MCP client.
     */
    McpToolResult execute(JsonRpcParamsBase arguments, McpRequestContext context);
}
