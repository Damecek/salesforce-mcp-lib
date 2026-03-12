/**
 * @description Contract for reading a registered MCP resource.
 */
public interface McpResourceExecutor {
    /**
     * @description Resolves resource content.
     * @param resourceUri Resource URI.
     * @param context Invocation context for this request.
     * @return Typed resource payload returned to MCP client.
     */
    McpResourceResult read(String resourceUri, McpRequestContext context);
}
