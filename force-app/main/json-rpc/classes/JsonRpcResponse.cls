/**
 * Envelope for a single JSON-RPC 2.0 response (success or error).
 *
 * Use the static factory methods {@link #success(JsonRpcIdValue, Object)}
 * and {@link #failure(JsonRpcIdValue, JsonRpcError)} to create instances
 * rather than calling the constructor directly.
 */
public class JsonRpcResponse {

    /** The request ID this response corresponds to. */
    public JsonRpcIdValue id;

    /**
     * Internal discriminator: {@code true} when the response carries a
     * result, {@code false} when it carries an error.
     */
    public Boolean hasResult;

    /** The result value for a successful response. */
    public Object result;

    /** The error object for a failed response. */
    public JsonRpcError error;

    // ── Factory methods ──────────────────────────────────────────────

    /**
     * Creates a successful JSON-RPC response.
     *
     * @param id     The request ID.
     * @param result The result payload.
     * @return A new success response.
     */
    public static JsonRpcResponse success(JsonRpcIdValue id, Object result) {
        JsonRpcResponse resp = new JsonRpcResponse();
        resp.id = id;
        resp.hasResult = true;
        resp.result = result;
        return resp;
    }

    /**
     * Creates an error JSON-RPC response.
     *
     * @param id    The request ID (may wrap null when the id could not be determined).
     * @param error The error descriptor.
     * @return A new error response.
     */
    public static JsonRpcResponse failure(JsonRpcIdValue id, JsonRpcError error) {
        JsonRpcResponse resp = new JsonRpcResponse();
        resp.id = id;
        resp.hasResult = false;
        resp.error = error;
        return resp;
    }
}
