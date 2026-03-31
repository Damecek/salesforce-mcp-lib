/**
 * Main entry point for the Salesforce MCP server framework.
 *
 * <p>Provides a programmatic registration API for MCP tools, resources,
 * resource templates, and prompts and dispatches incoming HTTP requests
 * through the JSON-RPC runtime. Subscriber developers create an instance,
 * register their capabilities, and delegate incoming
 * {@code RestRequest}/{@code RestResponse} pairs to {@link #handleRequest}.</p>
 *
 * <p>Example usage in a Salesforce REST resource:</p>
 * <pre>
 * McpServer server = new McpServer();
 * server.registerTool(new MyCustomTool());
 * server.registerResource(new MyResource());
 * server.registerPrompt(new MyPrompt());
 * server.handleRequest(RestContext.request, RestContext.response);
 * </pre>
 */
public class McpServer {

    private final List<McpToolDefinition> tools;
    private final Set<String> toolNames;

    private final List<McpResourceDefinition> resources;
    private final Set<String> resourceUris;

    private final List<McpResourceTemplateDefinition> resourceTemplates;
    private final Set<String> resourceTemplateUris;

    private final List<McpPromptDefinition> prompts;
    private final Set<String> promptNames;

    /**
     * Constructs a new MCP server with empty registries.
     */
    public McpServer() {
        this.tools = new List<McpToolDefinition>();
        this.toolNames = new Set<String>();
        this.resources = new List<McpResourceDefinition>();
        this.resourceUris = new Set<String>();
        this.resourceTemplates = new List<McpResourceTemplateDefinition>();
        this.resourceTemplateUris = new Set<String>();
        this.prompts = new List<McpPromptDefinition>();
        this.promptNames = new Set<String>();
    }

    /**
     * Registers a tool definition with this server.
     *
     * <p>Each tool must have a unique name. Attempting to register a tool
     * whose name conflicts with an already-registered tool throws a
     * {@link McpExceptions.DuplicateRegistrationException}.</p>
     *
     * @param tool The tool definition to register.
     * @throws McpExceptions.DuplicateRegistrationException if a tool with the same name is already registered.
     */
    public void registerTool(McpToolDefinition tool) {
        if (this.toolNames.contains(tool.name)) {
            throw new McpExceptions.DuplicateRegistrationException(
                'Tool already registered: ' + tool.name
            );
        }
        this.toolNames.add(tool.name);
        this.tools.add(tool);
    }

    /**
     * Registers a resource definition with this server.
     *
     * <p>Each resource must have a unique URI. Attempting to register a resource
     * whose URI conflicts with an already-registered resource throws a
     * {@link McpExceptions.DuplicateRegistrationException}.</p>
     *
     * @param resource The resource definition to register.
     * @throws McpExceptions.DuplicateRegistrationException if a resource with the same URI is already registered.
     */
    public void registerResource(McpResourceDefinition resource) {
        if (this.resourceUris.contains(resource.uri)) {
            throw new McpExceptions.DuplicateRegistrationException(
                'Resource already registered: ' + resource.uri
            );
        }
        this.resourceUris.add(resource.uri);
        this.resources.add(resource);
    }

    /**
     * Registers a resource template definition with this server.
     *
     * <p>Each template must have a unique URI template. Attempting to register
     * a template whose URI template conflicts with an already-registered template
     * throws a {@link McpExceptions.DuplicateRegistrationException}.</p>
     *
     * @param template The resource template definition to register.
     * @throws McpExceptions.DuplicateRegistrationException if a template with the same URI template is already registered.
     */
    public void registerResourceTemplate(McpResourceTemplateDefinition template) {
        if (this.resourceTemplateUris.contains(template.uriTemplate)) {
            throw new McpExceptions.DuplicateRegistrationException(
                'Resource template already registered: ' + template.uriTemplate
            );
        }
        this.resourceTemplateUris.add(template.uriTemplate);
        this.resourceTemplates.add(template);
    }

    /**
     * Registers a prompt definition with this server.
     *
     * <p>Each prompt must have a unique name. Attempting to register a prompt
     * whose name conflicts with an already-registered prompt throws a
     * {@link McpExceptions.DuplicateRegistrationException}.</p>
     *
     * @param prompt The prompt definition to register.
     * @throws McpExceptions.DuplicateRegistrationException if a prompt with the same name is already registered.
     */
    public void registerPrompt(McpPromptDefinition prompt) {
        if (this.promptNames.contains(prompt.name)) {
            throw new McpExceptions.DuplicateRegistrationException(
                'Prompt already registered: ' + prompt.name
            );
        }
        this.promptNames.add(prompt.name);
        this.prompts.add(prompt);
    }

    /**
     * Processes an incoming MCP request over HTTP.
     *
     * <p>Reads the JSON-RPC request body from the {@code RestRequest}, dispatches
     * it through the configured handler module, and writes the response back to
     * the {@code RestResponse}. Notifications (requests with no {@code id}) produce
     * no response body.</p>
     *
     * @param req The Salesforce {@code RestRequest} containing the JSON-RPC payload.
     * @param res The Salesforce {@code RestResponse} to write the result to.
     */
    public void handleRequest(RestRequest req, RestResponse res) {
        McpHttpTransport transport = new McpHttpTransport(req, res);
        String body = transport.getRequestBody();

        JsonRpcModule module = new McpJsonRpcModuleBuilder(
            this.tools,
            this.resources,
            this.resourceTemplates,
            this.prompts
        ).build();

        JsonRpcServiceRuntimeOptions options = new JsonRpcServiceRuntimeOptions();
        options.exceptionMapper = new McpJsonRpcExceptionMapper();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(body, module, options);

        if (result.hasResponse) {
            transport.setResponseBody(result.toJson());
        }
    }
}
