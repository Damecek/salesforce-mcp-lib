/**
 * @description Initialize client metadata provided by the MCP consumer.
 */
public inherited sharing class McpInitializeClientInfo {
    public String name;
    public String title;
    public String version;

    /**
     * @description Loads client info fields from a raw object.
     * @param rawClientInfo Raw value from the JSON-RPC envelope.
     */
    public void loadFromRaw(Object rawClientInfo) {
        if (!(rawClientInfo instanceof Map<String, Object>)) {
            throw new McpExceptions.InvalidParamsException('initialize requires clientInfo to be an object when present.');
        }

        Map<String, Object> rawMap = (Map<String, Object>) rawClientInfo;

        Object rawName = rawMap.get('name');
        if (rawName instanceof String) {
            this.name = (String) rawName;
        }

        Object rawTitle = rawMap.get('title');
        if (rawTitle instanceof String) {
            this.title = (String) rawTitle;
        }

        Object rawVersion = rawMap.get('version');
        if (rawVersion instanceof String) {
            this.version = (String) rawVersion;
        }
    }
}
