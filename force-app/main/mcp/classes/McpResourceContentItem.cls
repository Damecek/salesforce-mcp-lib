/**
 * @description Typed MCP resource content entry.
 */
public inherited sharing class McpResourceContentItem {
    public String uri;
    public String mimeType;
    public String text;

    public McpResourceContentItem() {
    }

    /**
     * @description Creates a resource content item.
     * @param resourceUri Resource URI.
     * @param value Text content.
     * @param contentType MIME type.
     */
    public McpResourceContentItem(String resourceUri, String value, String contentType) {
        this.uri = resourceUri;
        this.text = value;
        this.mimeType = contentType;
    }

    /**
     * @description Validates required fields.
     */
    public void validate() {
        if (String.isBlank(this.uri)) {
            throw new McpInvalidParamsException('Resource content uri is required.');
        }
    }
}
