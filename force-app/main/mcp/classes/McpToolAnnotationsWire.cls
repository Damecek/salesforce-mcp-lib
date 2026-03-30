/**
 * Wire-format serialization wrapper for {@link McpToolAnnotations}.
 *
 * <p>Mirrors the annotation fields with names suitable for JSON
 * serialization. Use {@link #fromAnnotations(McpToolAnnotations)} to
 * convert from the domain object to this wire representation.</p>
 */
public class McpToolAnnotationsWire {

    /** Hint that the tool only reads data and has no side effects. */
    public Boolean readOnlyHint;

    /** Hint that the tool may perform destructive or irreversible changes. */
    public Boolean destructiveHint;

    /** Hint that repeated calls with the same arguments yield the same result. */
    public Boolean idempotentHint;

    /** Hint that the tool interacts with systems outside the server's control. */
    public Boolean openWorldHint;

    /**
     * Converts an {@link McpToolAnnotations} instance to its wire-format
     * representation.
     *
     * @param ann the domain annotations to convert
     * @return wire-format instance, or {@code null} if the input is {@code null}
     */
    public static McpToolAnnotationsWire fromAnnotations(McpToolAnnotations ann) {
        if (ann == null) {
            return null;
        }
        McpToolAnnotationsWire wire = new McpToolAnnotationsWire();
        wire.readOnlyHint = ann.readOnlyHint;
        wire.destructiveHint = ann.destructiveHint;
        wire.idempotentHint = ann.idempotentHint;
        wire.openWorldHint = ann.openWorldHint;
        return wire;
    }
}
