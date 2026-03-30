/**
 * Result payload for the MCP {@code initialize} response.
 *
 * <p>Contains the negotiated protocol version, the server's declared
 * capabilities, identifying server information, and optional
 * instructions for the client.</p>
 */
public class McpInitializeResult extends JsonRpcResultBase {

    /** The MCP protocol version the server supports. */
    public String protocolVersion;

    /** Server capabilities advertised for this session. */
    public Map<String, Object> capabilities;

    /** Identifying information about the server. */
    public McpInitializeServerInfo serverInfo;

    /** Optional human-readable instructions for the client. */
    public String instructions;
}
