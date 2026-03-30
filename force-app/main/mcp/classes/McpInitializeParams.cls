/**
 * Parameters for the MCP {@code initialize} request.
 *
 * <p>Carries the client's protocol version, declared capabilities, and
 * identifying information so the server can negotiate the session.</p>
 */
public class McpInitializeParams extends JsonRpcParamsBase {

    /** The MCP protocol version the client supports. */
    public String protocolVersion;

    /** Capabilities the client declares for this session. */
    public McpInitializeCapabilities capabilities;

    /** Identifying information about the connecting client. */
    public McpInitializeClientInfo clientInfo;
}
