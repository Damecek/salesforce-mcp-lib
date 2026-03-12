/**
 * @description Typed MCP resource content entry.
 */
public inherited sharing class McpResourceContentItem {
    public String uri;
    public String mimeType;
    public String text;

    public McpResourceContentItem() {
    }

    public McpResourceContentItem(String resourceUri, String value, String contentType) {
        this.uri = resourceUri;
        this.text = value;
        this.mimeType = contentType;
    }

    public void validate() {
        if (String.isBlank(this.uri)) {
            throw new McpInvalidParamsException('Resource content uri is required.');
        }
    }
}
