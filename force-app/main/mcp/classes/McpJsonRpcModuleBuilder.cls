/**
 * Configures a {@link JsonRpcModule} with the full set of MCP method handlers.
 *
 * <p>Registers handlers for session lifecycle ({@code initialize},
 * {@code notifications/initialized}, {@code ping}) and tool operations
 * ({@code tools/list}, {@code tools/call}). Resource and prompt handlers
 * will be added in later phases.</p>
 */
public class McpJsonRpcModuleBuilder extends JsonRpcModuleBuilder {

    private final List<McpToolDefinition> tools;
    private final List<Object> resources;
    private final List<Object> prompts;

    /**
     * Constructs the module builder with the server's registered definitions.
     *
     * @param tools     The list of registered tool definitions.
     * @param resources The list of registered resource definitions (forward compatibility).
     * @param prompts   The list of registered prompt definitions (forward compatibility).
     */
    public McpJsonRpcModuleBuilder(
        List<McpToolDefinition> tools,
        List<Object> resources,
        List<Object> prompts
    ) {
        this.tools = tools;
        this.resources = resources;
        this.prompts = prompts;
    }

    /**
     * Registers all MCP method handlers on the given module.
     *
     * @param module The JSON-RPC module to configure with MCP handlers.
     */
    public override void configure(JsonRpcModule module) {
        module.register(new McpInitializeHandler(this.tools, this.resources, this.prompts));
        module.register(new McpNotificationHandler('notifications/initialized'));
        module.register(new McpPingHandler());
        module.register(new McpToolsListHandler(this.tools));
        module.register(new McpToolsCallHandler(this.tools));
    }
}
