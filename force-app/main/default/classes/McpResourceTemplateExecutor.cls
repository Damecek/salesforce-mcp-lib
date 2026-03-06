/**
 * @description Contract for resolving a registered MCP resource template.
 */
public interface McpResourceTemplateExecutor {
    /**
     * @description Resolves template output payload.
     * @param arguments Untyped template arguments.
     * @param context Invocation context for this request.
     * @return Arbitrary resolved payload returned to MCP client.
     */
    Object resolve(Map<String, Object> arguments, McpRequestContext context);
}
