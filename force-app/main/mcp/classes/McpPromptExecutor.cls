/**
 * @description Contract for resolving a registered MCP prompt.
 */
public interface McpPromptExecutor {
    /**
     * @description Resolves prompt payload.
     * @param arguments Typed prompt arguments DTO declared by the prompt definition.
     * @param context Invocation context for this request.
     * @return Typed prompt payload.
     */
    McpPromptResult resolve(JsonRpcParamsBase arguments, McpRequestContext context);
}
