/**
 * @description JSON-RPC params DTO for initialize.
 */
public inherited sharing class McpInitializeParams extends JsonRpcParamsBase {
    public String protocolVersion;
    public Map<String, Object> capabilities;
    public McpInitializeClientInfo clientInfo;

    /**
     * @description Loads initialize params from the raw params value.
     * @param rawParams Raw params value from the JSON-RPC envelope.
     */
    public void loadFromRaw(Object rawParams) {
        if (rawParams != null && !(rawParams instanceof Map<String, Object>)) {
            throw new McpExceptions.InvalidParamsException('initialize requires params to be an object.');
        }

        if (rawParams == null) {
            return;
        }

        Map<String, Object> rawMap = (Map<String, Object>) rawParams;

        Object rawProtocolVersion = rawMap.get('protocolVersion');
        if (rawProtocolVersion instanceof String) {
            this.protocolVersion = (String) rawProtocolVersion;
        }

        if (rawMap.containsKey('capabilities')) {
            Object rawCapabilities = rawMap.get('capabilities');
            if (rawCapabilities != null && !(rawCapabilities instanceof Map<String, Object>)) {
                throw new McpExceptions.InvalidParamsException('initialize requires capabilities to be an object when present.');
            }
            this.capabilities = (Map<String, Object>) rawCapabilities;
        }

        if (rawMap.containsKey('clientInfo')) {
            Object rawClientInfo = rawMap.get('clientInfo');
            if (rawClientInfo == null) {
                return;
            }
            this.clientInfo = new McpInitializeClientInfo();
            this.clientInfo.loadFromRaw(rawClientInfo);
        }
    }
}
