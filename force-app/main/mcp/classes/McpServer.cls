/**
 * Main entry point for the Salesforce MCP server framework.
 *
 * <p>Provides a programmatic registration API for MCP tool definitions and
 * dispatches incoming HTTP requests through the JSON-RPC runtime. Subscriber
 * developers create an instance, register their tools, and delegate incoming
 * {@code RestRequest}/{@code RestResponse} pairs to {@link #handleRequest}.</p>
 *
 * <p>Example usage in a Salesforce REST resource:</p>
 * <pre>
 * McpServer server = new McpServer();
 * server.registerTool(new MyCustomTool());
 * server.handleRequest(RestContext.request, RestContext.response);
 * </pre>
 */
public class McpServer {

    private final List<McpToolDefinition> tools;
    private final Set<String> toolNames;

    /**
     * Constructs a new MCP server with empty registries.
     */
    public McpServer() {
        this.tools = new List<McpToolDefinition>();
        this.toolNames = new Set<String>();
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
            new List<Object>(),
            new List<Object>()
        ).build();

        JsonRpcServiceRuntimeOptions options = new JsonRpcServiceRuntimeOptions();
        options.exceptionMapper = new McpJsonRpcExceptionMapper();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(body, module, options);

        if (result.hasResponse) {
            transport.setResponseBody(result.toJson());
        }
    }
}
