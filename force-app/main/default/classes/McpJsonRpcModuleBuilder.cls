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

    private abstract inherited sharing class BaseHandler implements JsonRpcMethodHandler {
        protected McpServer server;
        protected String method;
        protected Type paramsTypeValue;
        protected Type resultTypeValue;

        protected BaseHandler(McpServer sourceServer, String methodName, Type paramsTypeRef, Type resultTypeRef) {
            this.server = sourceServer;
            this.method = methodName;
            this.paramsTypeValue = paramsTypeRef;
            this.resultTypeValue = resultTypeRef;
        }

        public String methodName() { return this.method; }
        public Type paramsType() { return this.paramsTypeValue; }
        public Type resultType() { return this.resultTypeValue; }

        protected McpRequestContext mcpContext(JsonRpcInvocationContext context) {
            return McpRequestContext.fromJsonRpc(context);
        }
    }

    private inherited sharing class InitializeHandler extends BaseHandler {
        private InitializeHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_INITIALIZE, InitializeParams.class, InitializeResult.class);
        }

        public Object invoke(Object params, JsonRpcInvocationContext context) {
            InitializeResult result = new InitializeResult();
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
            super(sourceServer, METHOD_TOOLS_LIST, EmptyParams.class, ToolsListResult.class);
        }

        public Object invoke(Object params, JsonRpcInvocationContext context) {
            ToolsListResult result = new ToolsListResult();
            for (McpToolDefinition definition : this.server.listTools()) {
                result.tools.add(definition.toMap());
            }
            return result;
        }
    }

    private inherited sharing class ToolsCallHandler extends BaseHandler {
        private ToolsCallHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_TOOLS_CALL, ToolsCallParams.class, ToolsCallResult.class);
        }

        public Object invoke(Object params, JsonRpcInvocationContext context) {
            ToolsCallParams typed = (ToolsCallParams) params;
            Object payload = this.server.callTool(typed.name, typed.arguments, mcpContext(context));

            ToolsCallResult result = new ToolsCallResult();
            result.content = normalizeAsContentList(payload);
            result.isError = false;
            return result;
        }
    }

    private inherited sharing class ResourcesListHandler extends BaseHandler {
        private ResourcesListHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_RESOURCES_LIST, EmptyParams.class, ResourcesListResult.class);
        }

        public Object invoke(Object params, JsonRpcInvocationContext context) {
            ResourcesListResult result = new ResourcesListResult();
            for (McpResourceDefinition definition : this.server.listResources()) {
                result.resources.add(definition.toMap());
            }
            return result;
        }
    }

    private inherited sharing class ResourcesReadHandler extends BaseHandler {
        private ResourcesReadHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_RESOURCES_READ, ResourcesReadParams.class, ResourcesReadResult.class);
        }

        public Object invoke(Object params, JsonRpcInvocationContext context) {
            ResourcesReadParams typed = (ResourcesReadParams) params;
            Object payload = this.server.readResource(typed.uri, mcpContext(context));

            ResourcesReadResult result = new ResourcesReadResult();
            result.contents = normalizeAsResourceContents(typed.uri, payload);
            return result;
        }
    }

    private inherited sharing class ResourceTemplatesListHandler extends BaseHandler {
        private ResourceTemplatesListHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_RESOURCES_TEMPLATES_LIST, EmptyParams.class, ResourceTemplatesListResult.class);
        }

        public Object invoke(Object params, JsonRpcInvocationContext context) {
            ResourceTemplatesListResult result = new ResourceTemplatesListResult();
            for (McpResourceTemplateDefinition definition : this.server.listResourceTemplates()) {
                result.resourceTemplates.add(definition.toMap());
            }
            return result;
        }
    }

    private inherited sharing class ResourceTemplatesCallHandler extends BaseHandler {
        private ResourceTemplatesCallHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_RESOURCES_TEMPLATES_CALL, ResourceTemplatesCallParams.class, ResourceTemplatesCallResult.class);
        }

        public Object invoke(Object params, JsonRpcInvocationContext context) {
            ResourceTemplatesCallParams typed = (ResourceTemplatesCallParams) params;
            Object payload = this.server.callResourceTemplate(typed.name, typed.arguments, mcpContext(context));

            ResourceTemplatesCallResult result = new ResourceTemplatesCallResult();
            result.contents = normalizeAsResourceContents(typed.name, payload);
            return result;
        }
    }

    private inherited sharing class PromptsListHandler extends BaseHandler {
        private PromptsListHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_PROMPTS_LIST, EmptyParams.class, PromptsListResult.class);
        }

        public Object invoke(Object params, JsonRpcInvocationContext context) {
            PromptsListResult result = new PromptsListResult();
            for (McpPromptDefinition definition : this.server.listPrompts()) {
                result.prompts.add(definition.toMap());
            }
            return result;
        }
    }

    private inherited sharing class PromptsGetHandler extends BaseHandler {
        private PromptsGetHandler(McpServer sourceServer) {
            super(sourceServer, METHOD_PROMPTS_GET, PromptsGetParams.class, PromptsGetResult.class);
        }

        public Object invoke(Object params, JsonRpcInvocationContext context) {
            PromptsGetParams typed = (PromptsGetParams) params;
            Object payload = this.server.getPrompt(typed.name, typed.arguments, mcpContext(context));

            PromptsGetResult result = new PromptsGetResult();
            if (payload instanceof Map<String, Object>) {
                Map<String, Object> payloadMap = (Map<String, Object>) payload;
                if (payloadMap.get('description') instanceof String) {
                    result.description = (String) payloadMap.get('description');
                }
            }
            result.messages = normalizeAsPromptMessages(payload);
            return result;
        }
    }

    private static List<Object> normalizeAsContentList(Object payload) {
        if (payload == null) {
            return new List<Object>();
        }

        if (payload instanceof List<Object>) {
            return (List<Object>) payload;
        }

        if (payload instanceof Map<String, Object>) {
            return new List<Object>{ (Map<String, Object>) payload };
        }

        return new List<Object>{
            new Map<String, Object>{
                'type' => 'text',
                'text' => String.valueOf(payload)
            }
        };
    }

    private static List<Object> normalizeAsResourceContents(String key, Object payload) {
        if (payload instanceof Map<String, Object>) {
            Map<String, Object> payloadMap = (Map<String, Object>) payload;
            if (payloadMap.containsKey('contents') && payloadMap.get('contents') instanceof List<Object>) {
                return (List<Object>) payloadMap.get('contents');
            }
        }

        return new List<Object>{
            new Map<String, Object>{
                'uri' => key,
                'mimeType' => 'application/json',
                'text' => payload == null ? 'null' : JSON.serialize(payload)
            }
        };
    }

    private static List<Object> normalizeAsPromptMessages(Object payload) {
        if (payload == null) {
            return new List<Object>();
        }

        if (payload instanceof Map<String, Object>) {
            Map<String, Object> payloadMap = (Map<String, Object>) payload;
            if (payloadMap.containsKey('messages') && payloadMap.get('messages') instanceof List<Object>) {
                return (List<Object>) payloadMap.get('messages');
            }
            if (payloadMap.containsKey('role') && payloadMap.containsKey('content')) {
                return new List<Object>{ payloadMap };
            }
        }

        if (payload instanceof List<Object>) {
            List<Object> payloadList = (List<Object>) payload;
            if (!payloadList.isEmpty() && payloadList[0] instanceof Map<String, Object>) {
                Map<String, Object> firstEntry = (Map<String, Object>) payloadList[0];
                if (firstEntry.containsKey('role') && firstEntry.containsKey('content')) {
                    return payloadList;
                }
            }
        }

        return new List<Object>{
            new Map<String, Object>{
                'role' => 'user',
                'content' => normalizeAsContentList(payload)
            }
        };
    }

    private class EmptyParams extends JsonRpcParamsBase {
    }

    private class InitializeParams extends JsonRpcParamsBase {
        public String protocolVersion;
        public Map<String, Object> capabilities;
        public Map<String, Object> clientInfo;
    }

    private class InitializeResult extends JsonRpcResultBase {
        public String protocolVersion;
        public InitializeCapabilities capabilities = new InitializeCapabilities();
        public InitializeServerInfo serverInfo = new InitializeServerInfo();
    }

    private class InitializeCapabilities {
        public InitializeCapabilityEntry tools = new InitializeCapabilityEntry();
        public InitializeCapabilityEntry resources = new InitializeCapabilityEntry();
        public InitializeCapabilityEntry prompts = new InitializeCapabilityEntry();
    }

    private class InitializeCapabilityEntry {
        public Boolean listChanged = false;
    }

    private class InitializeServerInfo {
        public String name;
        public String version;
    }

    private class ToolsListResult extends JsonRpcResultBase {
        public List<Object> tools = new List<Object>();
    }

    private abstract class NamedArgumentsParams extends JsonRpcParamsBase implements JsonRpcRawParamsDecoder {
        public String name;
        public Map<String, Object> arguments;
        private Boolean hasInvalidParamsShape = false;
        private Boolean hasInvalidArgumentsShape = false;

        protected abstract String methodNameForValidation();

        public void decodeRawParams(Object rawParams) {
            this.hasInvalidParamsShape = rawParams != null && !(rawParams instanceof Map<String, Object>);
            if (this.hasInvalidParamsShape) {
                return;
            }

            if (!(rawParams instanceof Map<String, Object>)) {
                return;
            }

            Map<String, Object> rawMap = (Map<String, Object>) rawParams;
            Object rawName = rawMap.get('name');
            if (rawName instanceof String) {
                this.name = (String) rawName;
            }

            if (!rawMap.containsKey('arguments') || rawMap.get('arguments') == null) {
                return;
            }

            Object rawArguments = rawMap.get('arguments');
            if (!(rawArguments instanceof Map<String, Object>)) {
                this.hasInvalidArgumentsShape = true;
                return;
            }

            this.arguments = (Map<String, Object>) rawArguments;
        }

        public override void validate() {
            if (this.hasInvalidParamsShape) {
                throw new McpExceptions.InvalidParamsException(this.methodNameForValidation() + ' requires params to be an object.');
            }
            if (String.isBlank(this.name)) {
                throw new McpExceptions.InvalidParamsException(this.methodNameForValidation() + ' requires non-empty name.');
            }
            if (this.hasInvalidArgumentsShape) {
                throw new McpExceptions.InvalidParamsException(this.methodNameForValidation() + ' requires arguments to be an object when present.');
            }
        }
    }

    private class ToolsCallParams extends NamedArgumentsParams {
        protected override String methodNameForValidation() {
            return METHOD_TOOLS_CALL;
        }
    }

    private class ToolsCallResult extends JsonRpcResultBase {
        public List<Object> content = new List<Object>();
        public Boolean isError = false;
    }

    private class ResourcesListResult extends JsonRpcResultBase {
        public List<Object> resources = new List<Object>();
    }

    private class ResourcesReadParams extends JsonRpcParamsBase {
        public String uri;

        public override void validate() {
            if (String.isBlank(this.uri)) {
                throw new McpExceptions.InvalidParamsException('resources/read requires non-empty uri.');
            }
        }
    }

    private class ResourcesReadResult extends JsonRpcResultBase {
        public List<Object> contents = new List<Object>();
    }

    private class ResourceTemplatesListResult extends JsonRpcResultBase {
        public List<Object> resourceTemplates = new List<Object>();
    }

    private class ResourceTemplatesCallParams extends NamedArgumentsParams {
        protected override String methodNameForValidation() {
            return METHOD_RESOURCES_TEMPLATES_CALL;
        }
    }

    private class ResourceTemplatesCallResult extends JsonRpcResultBase {
        public List<Object> contents = new List<Object>();
    }

    private class PromptsListResult extends JsonRpcResultBase {
        public List<Object> prompts = new List<Object>();
    }

    private class PromptsGetParams extends NamedArgumentsParams {
        protected override String methodNameForValidation() {
            return METHOD_PROMPTS_GET;
        }
    }

    private class PromptsGetResult extends JsonRpcResultBase {
        public String description;
        public List<Object> messages = new List<Object>();
    }
}
