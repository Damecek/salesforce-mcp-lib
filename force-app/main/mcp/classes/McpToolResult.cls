/**
 * Result returned by {@link McpToolDefinition#execute(Map)}.
 *
 * <p>Extends {@link JsonRpcResultBase} so it can be serialized directly
 * into the {@code result} member of a JSON-RPC success response.</p>
 *
 * <p>When {@link #isError} is {@code true}, the content blocks describe
 * the error condition rather than a successful outcome.</p>
 */
public class McpToolResult extends JsonRpcResultBase {

    /** Content blocks returned by the tool. */
    public List<McpTextContent> content;

    /**
     * Indicates whether the tool encountered an error.
     *
     * <p>{@code null} or {@code false} signals success; {@code true}
     * signals a tool-level error whose details are in {@link #content}.</p>
     */
    public Boolean isError;
}
