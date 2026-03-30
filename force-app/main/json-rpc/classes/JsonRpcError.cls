/**
 * Standard JSON-RPC 2.0 error object.
 *
 * Instances are typically created via the static factory methods that map
 * to the pre-defined error codes in the specification:
 * <ul>
 *   <li>{@link #parseError(String)}       -- -32700</li>
 *   <li>{@link #invalidRequest(String)}   -- -32600</li>
 *   <li>{@link #methodNotFound(String)}   -- -32601</li>
 *   <li>{@link #invalidParams(String)}    -- -32602</li>
 *   <li>{@link #internalError(String)}    -- -32603</li>
 * </ul>
 */
public class JsonRpcError {

    /** Machine-readable error code. */
    public Integer code;

    /** Human-readable error description. */
    public String message;

    /** Optional additional data about the error. */
    public Object data;

    /**
     * Constructs a new error with the given code and message.
     *
     * @param code    The integer error code.
     * @param message A short description of the error.
     */
    public JsonRpcError(Integer code, String message) {
        this.code = code;
        this.message = message;
    }

    // ── Standard error factories ─────────────────────────────────────

    /**
     * Creates a Parse error (-32700).
     *
     * @param message Description of what failed during parsing.
     * @return A new JsonRpcError instance.
     */
    public static JsonRpcError parseError(String message) {
        return new JsonRpcError(-32700, message);
    }

    /**
     * Creates an Invalid Request error (-32600).
     *
     * @param message Description of why the request is invalid.
     * @return A new JsonRpcError instance.
     */
    public static JsonRpcError invalidRequest(String message) {
        return new JsonRpcError(-32600, message);
    }

    /**
     * Creates a Method not found error (-32601).
     *
     * @param message Description including the method name that was not found.
     * @return A new JsonRpcError instance.
     */
    public static JsonRpcError methodNotFound(String message) {
        return new JsonRpcError(-32601, message);
    }

    /**
     * Creates an Invalid params error (-32602).
     *
     * @param message Description of the parameter validation failure.
     * @return A new JsonRpcError instance.
     */
    public static JsonRpcError invalidParams(String message) {
        return new JsonRpcError(-32602, message);
    }

    /**
     * Creates an Internal error (-32603).
     *
     * @param message Description of the internal error condition.
     * @return A new JsonRpcError instance.
     */
    public static JsonRpcError internalError(String message) {
        return new JsonRpcError(-32603, message);
    }
}
