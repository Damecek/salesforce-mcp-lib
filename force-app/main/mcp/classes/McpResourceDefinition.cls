/**
 * Abstract base class for MCP resource definitions.
 *
 * <p>Subscriber developers extend this class to expose read-only data to
 * AI agents via the MCP {@code resources/read} protocol. Each subclass
 * declares its URI, name, description, and MIME type, then implements
 * {@link #read()} to produce the resource content.</p>
 */
public abstract class McpResourceDefinition {

    /** The unique URI that identifies this resource. */
    public String uri;

    /** Human-readable name of the resource. */
    public String name;

    /** Optional human-readable description of the resource. */
    public String description;

    /** Optional MIME type hint for the resource content. */
    public String mimeType;

    /**
     * Reads the resource and returns its content.
     *
     * @return an {@link McpResourceResult} containing one or more content items
     */
    public abstract McpResourceResult read();
}
