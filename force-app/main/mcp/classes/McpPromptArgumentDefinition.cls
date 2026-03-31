/**
 * Defines a single argument for an MCP prompt definition.
 */
public class McpPromptArgumentDefinition {
    public String name;
    public String description;
    public Boolean required;

    public McpPromptArgumentDefinition(String name, String description, Boolean required) {
        this.name = name;
        this.description = description;
        this.required = required;
    }
}
