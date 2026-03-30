/**
 * Abstract base class for MCP tool definitions.
 *
 * <p>Subscriber developers extend this class to expose Salesforce logic as
 * MCP tools. Each subclass declares its name, description, input schema,
 * validation rules, and execution logic.</p>
 *
 * <p>The framework calls {@link #validate(Map)} before {@link #execute(Map)}.
 * If validation fails, the subclass should throw
 * {@link McpInvalidParamsException} with a descriptive message; the framework
 * translates this into an {@code isError: true} tool result.</p>
 */
public abstract class McpToolDefinition {

    /** Unique tool name. Set in the subclass constructor. */
    public String name;

    /** Human-readable description of the tool. Set in the subclass constructor. */
    public String description;

    /** Optional tool annotations providing hints to MCP clients. */
    public McpToolAnnotations annotations;

    /**
     * Defines the JSON Schema for this tool's input parameters.
     *
     * <p>Must return a {@code Map} mirroring the JSON Schema structure with
     * {@code "type": "object"} at the top level.</p>
     *
     * @return the input schema as a {@code Map<String, Object>}
     */
    public abstract Map<String, Object> inputSchema();

    /**
     * Validates the provided arguments before execution.
     *
     * <p>Called by the framework before {@link #execute(Map)}. Implementations
     * should throw {@link McpInvalidParamsException} with a descriptive message
     * when required fields are missing or values are invalid.</p>
     *
     * @param arguments deserialized tool arguments from the client
     * @throws McpInvalidParamsException if validation fails
     */
    public abstract void validate(Map<String, Object> arguments);

    /**
     * Executes the tool logic with validated arguments.
     *
     * <p>Only called if {@link #validate(Map)} succeeds without throwing.</p>
     *
     * @param arguments deserialized tool arguments from the client
     * @return an {@link McpToolResult} containing content blocks
     */
    public abstract McpToolResult execute(Map<String, Object> arguments);
}
