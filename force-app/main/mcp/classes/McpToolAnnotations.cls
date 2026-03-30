/**
 * Tool metadata annotations that provide hints to MCP clients.
 *
 * <p>These hints help clients decide how to present or gate tool
 * invocations (e.g. confirming destructive operations, caching
 * idempotent calls, etc.). All fields are optional; when {@code null}
 * the client applies its own defaults.</p>
 */
public class McpToolAnnotations {

    /** Hint that the tool only reads data and has no side effects. */
    public Boolean readOnlyHint;

    /** Hint that the tool may perform destructive or irreversible changes. */
    public Boolean destructiveHint;

    /** Hint that repeated calls with the same arguments yield the same result. */
    public Boolean idempotentHint;

    /** Hint that the tool interacts with systems outside the server's control. */
    public Boolean openWorldHint;
}
