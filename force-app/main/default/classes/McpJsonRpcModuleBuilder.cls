/**
 * @description Bridges MCP operations to ApexJsonRpc module handlers.
 */
public inherited sharing class McpJsonRpcModuleBuilder extends JsonRpcModuleBuilder {
    private static final String METHOD_INITIALIZE = 'initialize';
    private static final String METHOD_TOOLS_LIST = 'tools/list';
    private static final String METHOD_TOOLS_CALL = 'tools/call';
    private static final String METHOD_RESOURCES_LIST = 'resources/list';
    private static final String METHOD_RESOURCES_READ = 'resources/read';
    private static final String METHOD_RESOURCES_TEMPLATES_LIST = 'resources/templates/list';
    private static final String METHOD_RESOURCES_TEMPLATES_CALL = 'resources/templates/call';
    private static final String METHOD_PROMPTS_LIST = 'prompts/list';
    private static final String METHOD_PROMPTS_GET = 'prompts/get';

    private McpServer server;

    /**
     * @description Creates builder for a specific MCP server registry.
     * @param sourceServer Server registry instance.
     */
    public McpJsonRpcModuleBuilder(McpServer sourceServer) {
        this.server = sourceServer;
    }

    /**
     * @description Registers all MCP protocol handlers into JSON-RPC module.
     * @param module Target JSON-RPC module.
     */
    public override void configure(JsonRpcModule module) {
        if (module == null) {
            throw new McpInvalidParamsException('JsonRpcModule is required.');
        }

        if (this.server == null) {
            throw new McpInvalidParamsException('McpServer is required.');
        }

        module
            .register(new InitializeHandler(this.server))
            .register(new ToolsListHandler(this.server))
            .register(new ToolsCallHandler(this.server))
            .register(new ResourcesListHandler(this.server))
            .register(new ResourcesReadHandler(this.server))
            .register(new ResourceTemplatesListHandler(this.server))
            .register(new ResourceTemplatesCallHandler(this.server))
            .register(new PromptsListHandler(this.server))
            .register(new PromptsGetHandler(this.server));
    }

    private abstract inherited sharing class BaseHandler extends JsonRpcMethodHandler {
        protected McpServer server;

        protected BaseHandler(McpServer sourceServer, String methodName, Type paramsTypeRef, Type resultTypeRef) {
            super(methodName, paramsTypeRef, resultTypeRef);
            this.server = sourceServer;
        }

        protected McpRequestContext mcpContext(JsonRpcInvocationContext context) {
            return McpRequestContext.fromJsonRpc(context);
        }
    }

    private inherited sharing class InitializeHandler extends BaseHandler {
        private InitializeHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_INITIALIZE, McpEmptyParams.class, McpInitializeResult.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            McpInitializeParams typed = new McpInitializeParams();
            typed.loadFromRaw(context?.rawRequest.get('params'));

            McpInitializeResult result = new McpInitializeResult();
            result.protocolVersion = this.server.protocolVersion;
            result.serverInfo.name = this.server.serverName;
            result.serverInfo.version = this.server.serverVersion;
            result.capabilities.tools.listChanged = false;
            result.capabilities.resources.listChanged = false;
            result.capabilities.prompts.listChanged = false;
            return result;
        }
    }

    private inherited sharing class ToolsListHandler extends BaseHandler {
        private ToolsListHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_TOOLS_LIST, McpEmptyParams.class, McpToolsListResult.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            McpToolsListResult result = new McpToolsListResult();
            for (McpToolDefinition definition : this.server.listTools()) {
                result.tools.add(new McpListedTool(definition));
            }
            return result;
        }
    }

    private inherited sharing class ToolsCallHandler extends BaseHandler {
        private ToolsCallHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_TOOLS_CALL, McpEmptyParams.class, McpToolResult.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            McpToolCallRpcParams typed = new McpToolCallRpcParams();
            typed.loadFromRaw(context?.rawRequest.get('params'));
            typed.validate();

            JsonRpcParamsBase arguments = this.server.deserializeToolArguments(typed.name, typed.arguments);
            return this.server.callTool(typed.name, arguments, mcpContext(context));
        }
    }

    private inherited sharing class ResourcesListHandler extends BaseHandler {
        private ResourcesListHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_RESOURCES_LIST, McpEmptyParams.class, McpResourcesListResult.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            McpResourcesListResult result = new McpResourcesListResult();
            result.resources.addAll(this.server.listResources());
            return result;
        }
    }

    private inherited sharing class ResourcesReadHandler extends BaseHandler {
        private ResourcesReadHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_RESOURCES_READ, McpResourcesReadRpcParams.class, McpResourceResult.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            McpResourcesReadRpcParams typed = (McpResourcesReadRpcParams) params;
            return this.server.readResource(typed.uri, mcpContext(context));
        }
    }

    private inherited sharing class ResourceTemplatesListHandler extends BaseHandler {
        private ResourceTemplatesListHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_RESOURCES_TEMPLATES_LIST, McpEmptyParams.class, McpResourceTemplatesListResult.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            McpResourceTemplatesListResult result = new McpResourceTemplatesListResult();
            for (McpResourceTemplateDefinition definition : this.server.listResourceTemplates()) {
                result.resourceTemplates.add(new McpListedResourceTemplate(definition));
            }
            return result;
        }
    }

    private inherited sharing class ResourceTemplatesCallHandler extends BaseHandler {
        private ResourceTemplatesCallHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_RESOURCES_TEMPLATES_CALL, McpEmptyParams.class, McpResourceResult.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            McpResourceTemplateCallRpcParams typed = new McpResourceTemplateCallRpcParams();
            typed.loadFromRaw(context?.rawRequest.get('params'));
            typed.validate();

            JsonRpcParamsBase arguments = this.server.deserializeResourceTemplateArguments(typed.name, typed.arguments);
            return this.server.callResourceTemplate(typed.name, arguments, mcpContext(context));
        }
    }

    private inherited sharing class PromptsListHandler extends BaseHandler {
        private PromptsListHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_PROMPTS_LIST, McpEmptyParams.class, McpPromptsListResult.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            McpPromptsListResult result = new McpPromptsListResult();
            for (McpPromptDefinition definition : this.server.listPrompts()) {
                result.prompts.add(new McpListedPrompt(definition));
            }
            return result;
        }
    }

    private inherited sharing class PromptsGetHandler extends BaseHandler {
        private PromptsGetHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_PROMPTS_GET, McpEmptyParams.class, McpPromptResult.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            McpPromptGetRpcParams typed = new McpPromptGetRpcParams();
            typed.loadFromRaw(context?.rawRequest.get('params'));
            typed.validate();

            JsonRpcParamsBase arguments = this.server.deserializePromptArguments(typed.name, typed.arguments);
            return this.server.getPrompt(typed.name, arguments, mcpContext(context));
        }
    }
}
