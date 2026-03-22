/**
 * @description Typed JSON-RPC 2.0 response envelope for a single request.
 */
public inherited sharing class JsonRpcResponse {
    /** @description Raw request id value (String, Integer, Long, or null). */
    public Object id;
    /** @description True when this response carries a result; false when it carries an error. */
    public Boolean hasResult;
    /** @description Result payload; valid only when hasResult is true. */
    public Object result;
    /** @description Error payload; valid only when hasResult is false. */
    public JsonRpcError error;

    /**
     * @description Creates a success response.
     * @param idValue Request id.
     * @param resultPayload Method result.
     * @return Success response instance.
     */
    public static JsonRpcResponse successResponse(Object idValue, Object resultPayload) {
        JsonRpcResponse r = new JsonRpcResponse();
        r.id = idValue;
        r.hasResult = true;
        r.result = resultPayload;
        return r;
    }

    /**
     * @description Creates an error response.
     * @param idValue Request id (may be null for parse errors).
     * @param err Error payload.
     * @return Error response instance.
     */
    public static JsonRpcResponse errorResponse(Object idValue, JsonRpcError err) {
        JsonRpcResponse r = new JsonRpcResponse();
        r.id = idValue;
        r.hasResult = false;
        r.error = err;
        return r;
    }
}
