/**
 * Abstract base class for MCP prompt definitions.
 * Subscribers extend this to implement reusable prompt templates.
 */
public abstract class McpPromptDefinition {
    public String name;
    public String description;
    public List<McpPromptArgumentDefinition> arguments;

    /**
     * Generate prompt messages for the given arguments.
     * @param arguments Key-value map of prompt argument values
     * @return McpPromptResult containing the generated messages
     */
    public abstract McpPromptResult get(Map<String, String> arguments);
}
