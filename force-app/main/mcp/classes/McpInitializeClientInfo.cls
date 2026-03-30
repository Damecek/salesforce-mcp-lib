/**
 * Identifying information about the MCP client.
 *
 * <p>Sent by the client during the {@code initialize} handshake so the
 * server can log or adapt behavior based on the connecting client.</p>
 */
public class McpInitializeClientInfo {

    /** Human-readable name of the client application. */
    public String name;

    /** Version string of the client application. */
    public String version;
}
