/**
 * @description Contract for reading a registered MCP resource.
 */
public interface McpResourceExecutor {
    /**
     * @description Resolves resource content.
     * @param resourceUri Resource URI.
     * @param context Invocation context for this request.
     * @return Arbitrary resource payload returned to MCP client.
     */
    Object read(String resourceUri, McpRequestContext context);
}
