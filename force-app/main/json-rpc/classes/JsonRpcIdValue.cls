/**
 * @description Typed wrapper for a JSON-RPC 2.0 request identifier.
 * The value may be a String, Integer, Long, or null.
 */
public inherited sharing class JsonRpcIdValue {
    /** @description Raw id value as parsed from the JSON-RPC envelope. */
    public Object value;

    /**
     * @description Creates an id wrapper from a raw parsed value.
     * @param rawValue String, Integer, Long, or null.
     */
    public JsonRpcIdValue(Object rawValue) {
        this.value = rawValue;
    }
}
