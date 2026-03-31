/**
 * Handles the MCP {@code initialize} JSON-RPC request.
 *
 * <p>Negotiates the session by returning the server's protocol version,
 * advertised capabilities, and identifying information. Capabilities are
 * built dynamically from the tool, resource, resource template, and prompt
 * definitions registered with the server.</p>
 */
public class McpInitializeHandler extends JsonRpcMethodHandler {

    private static final String PROTOCOL_VERSION = '2025-11-25';
    private static final String SERVER_NAME = 'SalesforceMcpServer';
    private static final String SERVER_VERSION = '1.1.0';

    private final List<McpToolDefinition> tools;
    private final List<McpResourceDefinition> resources;
    private final List<McpResourceTemplateDefinition> resourceTemplates;
    private final List<McpPromptDefinition> prompts;

    /**
     * Constructs the initialize handler with the server's registered capabilities.
     *
     * @param tools             The list of registered tool definitions (may be empty).
     * @param resources         The list of registered resource definitions (may be empty).
     * @param resourceTemplates The list of registered resource template definitions (may be empty).
     * @param prompts           The list of registered prompt definitions (may be empty).
     */
    public McpInitializeHandler(
        List<McpToolDefinition> tools,
        List<McpResourceDefinition> resources,
        List<McpResourceTemplateDefinition> resourceTemplates,
        List<McpPromptDefinition> prompts
    ) {
        super('initialize', McpInitializeParams.class, McpInitializeResult.class);
        this.tools = tools;
        this.resources = resources;
        this.resourceTemplates = resourceTemplates;
        this.prompts = prompts;
    }

    /**
     * Builds and returns the {@code initialize} response containing the
     * negotiated protocol version, server capabilities, and server info.
     *
     * @param context The invocation context for this request.
     * @return A successful {@link JsonRpcResponse} wrapping the {@link McpInitializeResult}.
     */
    public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
        McpInitializeResult result = new McpInitializeResult();
        result.protocolVersion = PROTOCOL_VERSION;
        result.capabilities = buildCapabilities();

        McpInitializeServerInfo serverInfo = new McpInitializeServerInfo();
        serverInfo.name = SERVER_NAME;
        serverInfo.version = SERVER_VERSION;
        result.serverInfo = serverInfo;

        return JsonRpcResponse.success(context.requestId, result);
    }

    /**
     * Builds the capabilities map by including only the capability categories
     * that have at least one registered definition.
     *
     * @return A map of capability names to their (currently empty) configuration maps.
     */
    private Map<String, Object> buildCapabilities() {
        Map<String, Object> capabilities = new Map<String, Object>();
        if (this.tools != null && !this.tools.isEmpty()) {
            capabilities.put('tools', new Map<String, Object>());
        }
        Boolean hasResources = (this.resources != null && !this.resources.isEmpty())
            || (this.resourceTemplates != null && !this.resourceTemplates.isEmpty());
        if (hasResources) {
            capabilities.put('resources', new Map<String, Object>());
        }
        if (this.prompts != null && !this.prompts.isEmpty()) {
            capabilities.put('prompts', new Map<String, Object>());
        }
        return capabilities;
    }
}
