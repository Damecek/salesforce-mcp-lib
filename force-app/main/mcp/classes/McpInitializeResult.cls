/**
 * @description JSON-RPC result DTO for initialize.
 */
public inherited sharing class McpInitializeResult extends JsonRpcResultBase {
    public String protocolVersion;
    public McpInitializeCapabilities capabilities = new McpInitializeCapabilities();
    public McpInitializeServerInfo serverInfo = new McpInitializeServerInfo();
}
