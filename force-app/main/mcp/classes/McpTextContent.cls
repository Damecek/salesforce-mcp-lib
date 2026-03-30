/**
 * Text content block used across tools, resources, and prompts.
 *
 * <p>Represents a simple text payload in the MCP protocol wire format.
 * The {@code type} field is always {@code "text"}.</p>
 */
public class McpTextContent {

    /** Content type discriminator -- always {@code "text"}. */
    public String type;

    /** The text content payload. */
    public String text;

    /**
     * Creates a new text content block.
     *
     * @param text the text content
     */
    public McpTextContent(String text) {
        this.type = 'text';
        this.text = text;
    }
}
