/**
 * @description Typed MCP text content block.
 */
public inherited sharing class McpTextContent {
    public String type = 'text';
    public String text;

    public McpTextContent() {
    }

    public McpTextContent(String value) {
        this.text = value;
    }

    public void validate() {
        if (this.type != 'text') {
            throw new McpInvalidParamsException('Only text content is currently supported.');
        }

        if (this.text == null) {
            throw new McpInvalidParamsException('Text content value is required.');
        }
    }
}
