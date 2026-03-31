/**
 * Result returned by {@link McpResourceDefinition#read()}.
 *
 * <p>Extends {@link JsonRpcResultBase} so it can be serialized directly
 * into the {@code result} member of a JSON-RPC success response.</p>
 */
public class McpResourceResult extends JsonRpcResultBase {

    /** The content items that make up this resource response. */
    public List<McpResourceContentItem> contents;
}
