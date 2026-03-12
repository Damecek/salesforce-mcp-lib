/**
 * @description JSON-RPC params DTO for initialize.
 */
public inherited sharing class McpInitializeParams extends JsonRpcParamsBase {
    public String protocolVersion;
    public Map<String, Object> capabilities;
    public Map<String, Object> clientInfo;
}
