/**
 * Abstract base class for URI-templated MCP resource definitions.
 *
 * <p>Subscriber developers extend this class to expose dynamic resources
 * that are accessed via URI templates (RFC 6570). Each subclass declares
 * its URI template, name, description, and MIME type, then implements
 * {@link #read(Map)} to produce content for a given set of template
 * arguments.</p>
 */
public abstract class McpResourceTemplateDefinition {

    /** The URI template for this resource (e.g. {@code "org://users/{userId}"}). */
    public String uriTemplate;

    /** Human-readable name of the resource template. */
    public String name;

    /** Optional human-readable description of the resource template. */
    public String description;

    /** Optional MIME type hint for the resource content. */
    public String mimeType;

    /**
     * Reads the templated resource with the supplied arguments and returns
     * its content.
     *
     * @param templateArguments a map of template variable names to their values
     * @return an {@link McpResourceResult} containing one or more content items
     */
    public abstract McpResourceResult read(Map<String, String> templateArguments);
}
