/**
 * Container for MCP-layer exception types.
 *
 * <p>Groups domain-specific exceptions that do not warrant their own
 * top-level class file.</p>
 */
public class McpExceptions {

    /**
     * Thrown when a tool, resource, or prompt is registered with a name
     * that is already in use within the same registry.
     */
    public class DuplicateRegistrationException extends Exception {}
}
