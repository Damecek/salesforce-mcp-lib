/**
 * Identifying information about the MCP server.
 *
 * <p>Returned in the {@code initialize} response so the client knows
 * which server implementation and version it is connected to.</p>
 */
public class McpInitializeServerInfo {

    /** Human-readable name of the server application. */
    public String name;

    /** Version string of the server application. */
    public String version;
}
