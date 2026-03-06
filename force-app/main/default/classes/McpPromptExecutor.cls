/**
 * @description Contract for resolving a registered MCP prompt.
 */
public interface McpPromptExecutor {
    /**
     * @description Resolves prompt payload.
     * @param arguments Untyped prompt arguments.
     * @param context Invocation context for this request.
     * @return Prompt payload, typically map with messages.
     */
    Object resolve(Map<String, Object> arguments, McpRequestContext context);
}
