/**
 * @description Generic MCP server registry and JSON-RPC execution entry point.
 * @example
 * {@code
 * McpServer server = new McpServer('Salesforce MCP Library', '0.1.0');
 * JsonRpcExecutionResult result = server.execute(requestJson);
 * }
 */
public inherited sharing class McpServer {
    /** @description Display name returned from initialize response. */
    public String serverName;
    /** @description Server version returned from initialize response. */
    public String serverVersion;
    /** @description Protocol version returned from initialize response. */
    public String protocolVersion = '2025-06-18';

    private Map<String, McpToolDefinition> toolsByName = new Map<String, McpToolDefinition>();
    private Map<String, McpToolExecutor> toolExecutorsByName = new Map<String, McpToolExecutor>();

    private Map<String, McpResourceDefinition> resourcesByUri = new Map<String, McpResourceDefinition>();
    private Map<String, McpResourceExecutor> resourceExecutorsByUri = new Map<String, McpResourceExecutor>();

    private Map<String, McpResourceTemplateDefinition> templatesByName = new Map<String, McpResourceTemplateDefinition>();
    private Map<String, McpResourceTemplateExecutor> templateExecutorsByName = new Map<String, McpResourceTemplateExecutor>();

    private Map<String, McpPromptDefinition> promptsByName = new Map<String, McpPromptDefinition>();
    private Map<String, McpPromptExecutor> promptExecutorsByName = new Map<String, McpPromptExecutor>();

    /**
     * @description Creates a server with explicit name and version.
     * @param name Human-readable server name.
     * @param version Server version value.
     */
    public McpServer(String name, String version) {
        this.serverName = name;
        this.serverVersion = version;
    }

    /**
     * @description Creates a server with default identity.
     */
    public McpServer() {
        this('salesforce-mcp-lib', '0.1.0');
    }

    /**
     * @description Registers a tool descriptor and executor.
     * @param definition Tool descriptor.
     * @param executor Tool executor.
     * @return Same server for fluent chaining.
     */
    public McpServer registerTool(McpToolDefinition definition, McpToolExecutor executor) {
        if (definition == null || executor == null) {
            throw new McpInvalidParamsException('Tool definition and executor are required.');
        }

        definition.validate();
        if (this.toolsByName.containsKey(definition.name)) {
            throw new McpInvalidParamsException('Duplicate tool registration: ' + definition.name);
        }

        this.toolsByName.put(definition.name, definition);
        this.toolExecutorsByName.put(definition.name, executor);
        return this;
    }

    /**
     * @description Registers a resource descriptor and executor.
     * @param definition Resource descriptor.
     * @param executor Resource executor.
     * @return Same server for fluent chaining.
     */
    public McpServer registerResource(McpResourceDefinition definition, McpResourceExecutor executor) {
        if (definition == null || executor == null) {
            throw new McpInvalidParamsException('Resource definition and executor are required.');
        }

        definition.validate();
        if (this.resourcesByUri.containsKey(definition.uri)) {
            throw new McpInvalidParamsException('Duplicate resource registration: ' + definition.uri);
        }

        this.resourcesByUri.put(definition.uri, definition);
        this.resourceExecutorsByUri.put(definition.uri, executor);
        return this;
    }

    /**
     * @description Registers a resource template descriptor and executor.
     * @param definition Resource template descriptor.
     * @param executor Resource template executor.
     * @return Same server for fluent chaining.
     */
    public McpServer registerResourceTemplate(McpResourceTemplateDefinition definition, McpResourceTemplateExecutor executor) {
        if (definition == null || executor == null) {
            throw new McpInvalidParamsException('Resource template definition and executor are required.');
        }

        definition.validate();
        if (this.templatesByName.containsKey(definition.name)) {
            throw new McpInvalidParamsException('Duplicate resource template registration: ' + definition.name);
        }

        this.templatesByName.put(definition.name, definition);
        this.templateExecutorsByName.put(definition.name, executor);
        return this;
    }

    /**
     * @description Registers a prompt descriptor and executor.
     * @param definition Prompt descriptor.
     * @param executor Prompt executor.
     * @return Same server for fluent chaining.
     */
    public McpServer registerPrompt(McpPromptDefinition definition, McpPromptExecutor executor) {
        if (definition == null || executor == null) {
            throw new McpInvalidParamsException('Prompt definition and executor are required.');
        }

        definition.validate();
        if (this.promptsByName.containsKey(definition.name)) {
            throw new McpInvalidParamsException('Duplicate prompt registration: ' + definition.name);
        }

        this.promptsByName.put(definition.name, definition);
        this.promptExecutorsByName.put(definition.name, executor);
        return this;
    }

    /**
     * @description Returns currently registered tool descriptors.
     * @return Tool descriptors sorted by name.
     */
    public List<McpToolDefinition> listTools() {
        return sortToolDefinitions(this.toolsByName.values());
    }

    /**
     * @description Returns currently registered resource descriptors.
     * @return Resource descriptors sorted by URI.
     */
    public List<McpResourceDefinition> listResources() {
        return sortResourceDefinitions(this.resourcesByUri.values());
    }

    /**
     * @description Returns currently registered resource template descriptors.
     * @return Resource template descriptors sorted by name.
     */
    public List<McpResourceTemplateDefinition> listResourceTemplates() {
        return sortTemplateDefinitions(this.templatesByName.values());
    }

    /**
     * @description Returns currently registered prompt descriptors.
     * @return Prompt descriptors sorted by name.
     */
    public List<McpPromptDefinition> listPrompts() {
        return sortPromptDefinitions(this.promptsByName.values());
    }

    /**
     * @description Deserializes raw tool arguments into the tool's declared DTO type.
     * @param toolName Registered tool name.
     * @param rawArguments Raw arguments map from the protocol edge.
     * @return Typed DTO extending JsonRpcParamsBase.
     */
    public JsonRpcParamsBase deserializeToolArguments(String toolName, Map<String, Object> rawArguments) {
        McpToolDefinition definition = this.toolsByName.get(toolName);
        if (definition == null) {
            throw new McpExceptions.NotFoundException('Tool is not registered: ' + toolName);
        }

        return deserializeArguments(rawArguments, definition.argumentsType(), 'tools/call');
    }

    /**
     * @description Deserializes raw resource template arguments into the template's declared DTO type.
     * @param templateName Registered template name.
     * @param rawArguments Raw arguments map from the protocol edge.
     * @return Typed DTO extending JsonRpcParamsBase.
     */
    public JsonRpcParamsBase deserializeResourceTemplateArguments(String templateName, Map<String, Object> rawArguments) {
        McpResourceTemplateDefinition definition = this.templatesByName.get(templateName);
        if (definition == null) {
            throw new McpExceptions.NotFoundException('Resource template is not registered: ' + templateName);
        }

        return deserializeArguments(rawArguments, definition.argumentsType(), 'resources/templates/call');
    }

    /**
     * @description Deserializes raw prompt arguments into the prompt's declared DTO type.
     * @param promptName Registered prompt name.
     * @param rawArguments Raw arguments map from the protocol edge.
     * @return Typed DTO extending JsonRpcParamsBase.
     */
    public JsonRpcParamsBase deserializePromptArguments(String promptName, Map<String, Object> rawArguments) {
        McpPromptDefinition definition = this.promptsByName.get(promptName);
        if (definition == null) {
            throw new McpExceptions.NotFoundException('Prompt is not registered: ' + promptName);
        }

        return deserializeArguments(rawArguments, definition.argumentsType(), 'prompts/get');
    }

    /**
     * @description Executes a tool by name with typed arguments.
     * @param toolName Registered tool name.
     * @param arguments Typed arguments DTO.
     * @param context Invocation context.
     * @return Typed tool result returned by executor.
     */
    public McpToolResult callTool(String toolName, JsonRpcParamsBase arguments, McpRequestContext context) {
        McpToolExecutor executor = this.toolExecutorsByName.get(toolName);
        if (executor == null) {
            throw new McpExceptions.NotFoundException('Tool is not registered: ' + toolName);
        }

        McpToolResult result = executor.execute(arguments == null ? new JsonRpcParamsBase() : arguments, context);
        if (result == null) {
            throw new McpExceptions.InternalException('Tool executor returned null result.');
        }
        validateExecutorResult(result, 'Tool executor returned invalid result.');
        return result;
    }

    /**
     * @description Reads a resource by URI.
     * @param resourceUri Registered resource URI.
     * @param context Invocation context.
     * @return Typed resource payload returned by executor.
     */
    public McpResourceResult readResource(String resourceUri, McpRequestContext context) {
        McpResourceExecutor executor = this.resourceExecutorsByUri.get(resourceUri);
        if (executor == null) {
            throw new McpExceptions.NotFoundException('Resource is not registered: ' + resourceUri);
        }

        McpResourceResult result = executor.read(resourceUri, context);
        if (result == null) {
            throw new McpExceptions.InternalException('Resource executor returned null result.');
        }
        validateExecutorResult(result, 'Resource executor returned invalid result.');
        return result;
    }

    /**
     * @description Resolves a resource template by name with typed arguments.
     * @param templateName Registered template name.
     * @param arguments Typed arguments DTO.
     * @param context Invocation context.
     * @return Typed template payload returned by executor.
     */
    public McpResourceResult callResourceTemplate(String templateName, JsonRpcParamsBase arguments, McpRequestContext context) {
        McpResourceTemplateExecutor executor = this.templateExecutorsByName.get(templateName);
        if (executor == null) {
            throw new McpExceptions.NotFoundException('Resource template is not registered: ' + templateName);
        }

        McpResourceResult result = executor.resolve(arguments == null ? new JsonRpcParamsBase() : arguments, context);
        if (result == null) {
            throw new McpExceptions.InternalException('Resource template executor returned null result.');
        }
        validateExecutorResult(result, 'Resource template executor returned invalid result.');
        return result;
    }

    /**
     * @description Resolves a prompt by name with typed arguments.
     * @param promptName Registered prompt name.
     * @param arguments Typed arguments DTO.
     * @param context Invocation context.
     * @return Typed prompt payload returned by executor.
     */
    public McpPromptResult getPrompt(String promptName, JsonRpcParamsBase arguments, McpRequestContext context) {
        McpPromptExecutor executor = this.promptExecutorsByName.get(promptName);
        if (executor == null) {
            throw new McpExceptions.NotFoundException('Prompt is not registered: ' + promptName);
        }

        McpPromptResult result = executor.resolve(arguments == null ? new JsonRpcParamsBase() : arguments, context);
        if (result == null) {
            throw new McpExceptions.InternalException('Prompt executor returned null result.');
        }
        validateExecutorResult(result, 'Prompt executor returned invalid result.');
        return result;
    }

    /**
     * @description Builds a JSON-RPC module from current MCP registration state.
     * @return Configured JSON-RPC module.
     */
    public JsonRpcModule toJsonRpcModule() {
        return new McpJsonRpcModuleBuilder(this).build();
    }

    /**
     * @description Executes raw JSON-RPC payload against the current MCP registration state.
     * @param requestJson JSON-RPC request JSON.
     * @return JSON-RPC runtime execution result.
     */
    public JsonRpcExecutionResult execute(String requestJson) {
        JsonRpcServiceRuntimeOptions options = new JsonRpcServiceRuntimeOptions();
        options.exceptionMapper = new McpJsonRpcExceptionMapper();
        return JsonRpcServiceRuntime.execute(requestJson, this.toJsonRpcModule(), options);
    }

    private static JsonRpcParamsBase deserializeArguments(Map<String, Object> rawArguments, Type argumentsType, String operationName) {
        Type effectiveType = argumentsType == null ? JsonRpcParamsBase.class : argumentsType;
        if (String.valueOf(effectiveType) == String.valueOf(JsonRpcParamsBase.class)) {
            return new JsonRpcParamsBase();
        }

        Object probe;
        try {
            probe = effectiveType.newInstance();
        } catch (Exception ex) {
            throw new McpInvalidParamsException(operationName + ' arguments type must be instantiable.');
        }

        if (!(probe instanceof JsonRpcParamsBase)) {
            throw new McpInvalidParamsException(operationName + ' arguments type must extend JsonRpcParamsBase.');
        }

        JsonRpcParamsBase typedArguments = (JsonRpcParamsBase) probe;
        if (rawArguments != null) {
            try {
                typedArguments = (JsonRpcParamsBase) JSON.deserialize(JSON.serialize(rawArguments), effectiveType);
            } catch (Exception ex) {
                throw new McpExceptions.InvalidParamsException(operationName + ' arguments must match the declared DTO shape.');
            }
        }

        try {
            typedArguments.validate();
        } catch (McpExceptions.InvalidParamsException ex) {
            throw ex;
        } catch (McpInvalidParamsException ex) {
            throw new McpExceptions.InvalidParamsException(ex.getMessage());
        } catch (JsonRpcException ex) {
            throw new McpExceptions.InvalidParamsException(ex.getMessage());
        } catch (Exception ex) {
            throw new McpExceptions.InvalidParamsException(operationName + ' arguments failed validation.');
        }

        return typedArguments;
    }

    private static void validateExecutorResult(JsonRpcResultBase result, String errorMessage) {
        try {
            result.validate();
        } catch (Exception ex) {
            throw new McpExceptions.InternalException(errorMessage);
        }
    }

    private static List<McpToolDefinition> sortToolDefinitions(List<McpToolDefinition> values) {
        Map<String, McpToolDefinition> byName = new Map<String, McpToolDefinition>();
        List<String> keys = new List<String>();

        for (McpToolDefinition value : values) {
            byName.put(value.name, value);
            keys.add(value.name);
        }

        keys.sort();
        List<McpToolDefinition> sorted = new List<McpToolDefinition>();
        for (String key : keys) {
            sorted.add(byName.get(key));
        }

        return sorted;
    }

    private static List<McpResourceDefinition> sortResourceDefinitions(List<McpResourceDefinition> values) {
        Map<String, McpResourceDefinition> byUri = new Map<String, McpResourceDefinition>();
        List<String> keys = new List<String>();

        for (McpResourceDefinition value : values) {
            byUri.put(value.uri, value);
            keys.add(value.uri);
        }

        keys.sort();
        List<McpResourceDefinition> sorted = new List<McpResourceDefinition>();
        for (String key : keys) {
            sorted.add(byUri.get(key));
        }

        return sorted;
    }

    private static List<McpResourceTemplateDefinition> sortTemplateDefinitions(List<McpResourceTemplateDefinition> values) {
        Map<String, McpResourceTemplateDefinition> byName = new Map<String, McpResourceTemplateDefinition>();
        List<String> keys = new List<String>();

        for (McpResourceTemplateDefinition value : values) {
            byName.put(value.name, value);
            keys.add(value.name);
        }

        keys.sort();
        List<McpResourceTemplateDefinition> sorted = new List<McpResourceTemplateDefinition>();
        for (String key : keys) {
            sorted.add(byName.get(key));
        }

        return sorted;
    }

    private static List<McpPromptDefinition> sortPromptDefinitions(List<McpPromptDefinition> values) {
        Map<String, McpPromptDefinition> byName = new Map<String, McpPromptDefinition>();
        List<String> keys = new List<String>();

        for (McpPromptDefinition value : values) {
            byName.put(value.name, value);
            keys.add(value.name);
        }

        keys.sort();
        List<McpPromptDefinition> sorted = new List<McpPromptDefinition>();
        for (String key : keys) {
            sorted.add(byName.get(key));
        }

        return sorted;
    }
}
