/**
 * A message within an MCP prompt response.
 */
public class McpPromptMessage {
    public String role;
    public McpTextContent content;

    public McpPromptMessage(String role, McpTextContent content) {
        this.role = role;
        this.content = content;
    }
}
