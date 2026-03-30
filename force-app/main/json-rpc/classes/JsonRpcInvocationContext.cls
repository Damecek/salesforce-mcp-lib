/**
 * Per-request context passed to JSON-RPC method handlers.
 *
 * Carries the metadata and raw payload for the current request so that
 * handlers can access both typed parameters (via the framework) and the
 * original untyped map when needed.
 */
public class JsonRpcInvocationContext {

    /** The JSON-RPC method name being invoked. */
    public String methodName;

    /** The request ID for this invocation. */
    public JsonRpcIdValue requestId;

    /**
     * The full raw request as produced by
     * {@code JSON.deserializeUntyped()}.
     */
    public Map<String, Object> rawRequest;

    /**
     * Zero-based index within a batch request. For single requests
     * this is typically {@code 0}.
     */
    public Integer batchIndex;

    /**
     * Constructs a new invocation context.
     *
     * @param methodName  The JSON-RPC method name.
     * @param requestId   The request ID value.
     * @param rawRequest  The full raw deserialized request map.
     * @param batchIndex  The index in a batch (0 for single requests).
     */
    public JsonRpcInvocationContext(
        String methodName,
        JsonRpcIdValue requestId,
        Map<String, Object> rawRequest,
        Integer batchIndex
    ) {
        this.methodName = methodName;
        this.requestId = requestId;
        this.rawRequest = rawRequest;
        this.batchIndex = batchIndex;
    }
}
