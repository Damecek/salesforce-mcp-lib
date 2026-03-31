/**
 * Handles the MCP {@code initialize} JSON-RPC request.
 *
 * <p>Negotiates the session by returning the server's protocol version,
 * advertised capabilities, and identifying information. Capabilities are
 * built dynamically from the tool, resource, resource template, and prompt
 * definitions registered with the server.</p>
 */
public class McpInitializeHandler extends JsonRpcMethodHandler {

    private static final String LATEST_PROTOCOL_VERSION = '2025-11-25';
    private static final Set<String> SUPPORTED_PROTOCOL_VERSIONS = new Set<String>{
        '2025-11-25', '2025-06-18', '2025-03-26', '2024-11-05'
    };
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
        String clientVersion = getClientProtocolVersion(context.rawRequest);
        McpInitializeResult result = new McpInitializeResult();
        result.protocolVersion = negotiateProtocolVersion(clientVersion);
        result.capabilities = buildCapabilities();

        McpInitializeServerInfo serverInfo = new McpInitializeServerInfo();
        serverInfo.name = SERVER_NAME;
        serverInfo.version = SERVER_VERSION;
        result.serverInfo = serverInfo;

        return JsonRpcResponse.success(context.requestId, result);
    }

    /**
     * Extracts the client's requested protocol version from the raw request.
     *
     * @param rawRequest The full deserialized JSON-RPC request map.
     * @return The client's protocol version string, or null if absent.
     */
    private String getClientProtocolVersion(Map<String, Object> rawRequest) {
        if (rawRequest == null) {
            return null;
        }
        Object paramsObj = rawRequest.get('params');
        if (paramsObj instanceof Map<String, Object>) {
            Map<String, Object> paramsMap = (Map<String, Object>) paramsObj;
            Object version = paramsMap.get('protocolVersion');
            return version instanceof String ? (String) version : null;
        }
        return null;
    }

    /**
     * Negotiates the protocol version.
     *
     * <p>If the client's requested version is among the server's supported
     * versions, the server echoes it back (backward compatibility). Otherwise
     * the server returns its latest supported version and lets the client
     * decide whether to continue.</p>
     *
     * @param clientVersion The protocol version string sent by the client (may be null).
     * @return The negotiated protocol version string.
     */
    private String negotiateProtocolVersion(String clientVersion) {
        if (clientVersion != null && SUPPORTED_PROTOCOL_VERSIONS.contains(clientVersion)) {
            return clientVersion;
        }
        return LATEST_PROTOCOL_VERSION;
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
