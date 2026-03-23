/**
 * @description Contract for resolving a registered MCP resource template.
 */
public interface McpResourceTemplateExecutor {
    /**
     * @description Resolves template output payload.
     * @param arguments Typed template arguments DTO declared by the template definition.
     * @param context Invocation context for this request.
     * @return Typed resolved payload returned to MCP client.
     */
    McpResourceResult resolve(JsonRpcParamsBase arguments, McpRequestContext context);
}
