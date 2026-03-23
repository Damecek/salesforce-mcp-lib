/**
 * @description Base JSON-RPC params DTO for MCP methods that take name plus arguments object.
 */
public abstract inherited sharing class McpNamedArgumentsParams extends JsonRpcParamsBase {
    public String name;
    public Map<String, Object> arguments;

    protected abstract String methodNameForValidation();

    public override void validate() {
        if (String.isBlank(this.name)) {
            throw new McpExceptions.InvalidParamsException(this.methodNameForValidation() + ' requires non-empty name.');
        }
    }

    /**
     * @description Loads name and arguments from the raw params object.
     * @param rawParams Raw params value from the JSON-RPC envelope.
     */
    public void loadFromRaw(Object rawParams) {
        if (rawParams != null && !(rawParams instanceof Map<String, Object>)) {
            throw new McpExceptions.InvalidParamsException(this.methodNameForValidation() + ' requires params to be an object.');
        }

        if (rawParams == null) {
            return;
        }

        Map<String, Object> rawMap = (Map<String, Object>) rawParams;
        Object rawName = rawMap.get('name');
        if (rawName instanceof String) {
            this.name = (String) rawName;
        }

        if (!rawMap.containsKey('arguments') || rawMap.get('arguments') == null) {
            return;
        }

        Object rawArguments = rawMap.get('arguments');
        if (!(rawArguments instanceof Map<String, Object>)) {
            throw new McpExceptions.InvalidParamsException(this.methodNameForValidation() + ' requires arguments to be an object when present.');
        }

        this.arguments = (Map<String, Object>) rawArguments;
    }
}
