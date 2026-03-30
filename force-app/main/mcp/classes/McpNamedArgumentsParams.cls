/**
 * Params container for MCP methods that receive a dynamic {@code arguments}
 * map alongside a {@code name} identifier.
 *
 * <p>Used by {@code tools/call}, {@code prompts/get}, and similar handlers
 * that need to extract a named entity plus its freeform arguments from the
 * raw JSON-RPC {@code params} object.</p>
 */
public class McpNamedArgumentsParams extends JsonRpcParamsBase {

    /** The dynamic arguments map extracted from the raw request params. */
    protected Map<String, Object> arguments;

    /** The name identifier extracted from the raw request params. */
    public String name;

    /**
     * Loads the {@code arguments} map from a raw deserialized JSON-RPC
     * {@code params} object.
     *
     * <p>Extracts the value at key {@code "arguments"} and casts it to a
     * {@code Map<String, Object>}. Falls back to an empty map when the
     * key is absent or {@code null}.</p>
     *
     * @param rawParams the deserialized JSON-RPC {@code params} map
     */
    public void loadFromRaw(Map<String, Object> rawParams) {
        Object raw = rawParams.get('arguments');
        this.arguments = (raw != null)
            ? (Map<String, Object>) raw
            : new Map<String, Object>();
    }

    /**
     * Returns the dynamic arguments map.
     *
     * @return the arguments as a {@code Map<String, Object>}
     */
    public Map<String, Object> getArguments() {
        return this.arguments;
    }

    /**
     * Loads the {@code name} field from a raw deserialized JSON-RPC
     * {@code params} object.
     *
     * <p>Extracts the value at key {@code "name"} and casts it to a
     * {@code String}. Used by methods such as {@code tools/call} and
     * {@code prompts/get} that identify the target entity by name.</p>
     *
     * @param rawParams the deserialized JSON-RPC {@code params} map
     */
    public void loadName(Map<String, Object> rawParams) {
        this.name = (String) rawParams.get('name');
    }
}
