/**
 * Configures a {@link JsonRpcModule} with the full set of MCP method handlers.
 *
 * <p>Registers handlers for session lifecycle ({@code initialize},
 * {@code notifications/initialized}, {@code ping}), tool operations
 * ({@code tools/list}, {@code tools/call}), resource operations
 * ({@code resources/list}, {@code resources/read},
 * {@code resources/templates/list}, {@code resources/templates/call}),
 * and prompt operations ({@code prompts/list}, {@code prompts/get}).</p>
 */
public inherited sharing class McpJsonRpcModuleBuilder extends JsonRpcModuleBuilder {

    private final List<McpToolDefinition> tools;
    private final List<McpResourceDefinition> resources;
    private final List<McpResourceTemplateDefinition> resourceTemplates;
    private final List<McpPromptDefinition> prompts;

    /**
     * Constructs the module builder with the server's registered definitions.
     *
     * @param tools             The list of registered tool definitions.
     * @param resources         The list of registered resource definitions.
     * @param resourceTemplates The list of registered resource template definitions.
     * @param prompts           The list of registered prompt definitions.
     */
    public McpJsonRpcModuleBuilder(
        List<McpToolDefinition> tools,
        List<McpResourceDefinition> resources,
        List<McpResourceTemplateDefinition> resourceTemplates,
        List<McpPromptDefinition> prompts
    ) {
        this.tools = tools;
        this.resources = resources;
        this.resourceTemplates = resourceTemplates;
        this.prompts = prompts;
    }

    /**
     * Registers all MCP method handlers on the given module.
     *
     * @param module The JSON-RPC module to configure with MCP handlers.
     */
    public override void configure(JsonRpcModule module) {
        // Lifecycle handlers
        module.register(new McpInitializeHandler(this.tools, this.resources, this.resourceTemplates, this.prompts));
        module.register(new McpNotificationHandler('notifications/initialized'));
        module.register(new McpPingHandler());

        // Tool handlers
        module.register(new McpToolsListHandler(this.tools));
        module.register(new McpToolsCallHandler(this.tools));

        // Resource handlers
        module.register(new McpResourcesListHandler(this.resources));
        module.register(new McpResourcesReadHandler(this.resources));
        module.register(new McpResourcesTemplatesListHandler(this.resourceTemplates));
        module.register(new McpResourcesTemplatesCallHandler(this.resourceTemplates));

        // Prompt handlers
        module.register(new McpPromptsListHandler(this.prompts));
        module.register(new McpPromptsGetHandler(this.prompts));
    }
}
