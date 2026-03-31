/**
 * A single content item within an MCP resource response.
 *
 * <p>Contains either text content or base64-encoded binary content.
 * The {@link #text} and {@link #blob} fields are mutually exclusive --
 * a content item carries one or the other, never both.</p>
 */
public class McpResourceContentItem {

    /** The URI that identifies the resource this content belongs to. */
    public String uri;

    /** The MIME type of this content item (e.g. {@code "text/plain"}). */
    public String mimeType;

    /** Text content. Mutually exclusive with {@link #blob}. */
    public String text;

    /** Base64-encoded binary content. Mutually exclusive with {@link #text}. Serialized as "blob" on the wire. */
    public String blobData;
}
