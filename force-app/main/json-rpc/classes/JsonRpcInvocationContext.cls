/**
 * @description Execution context passed to a JSON-RPC 2.0 method handler invocation.
 */
public inherited sharing class JsonRpcInvocationContext {
    /** @description Resolved method name from the request envelope. */
    public String methodName;
    /** @description Typed request id; null for notifications. */
    public JsonRpcIdValue requestId;
    /** @description Full parsed request envelope including params. */
    public Map<String, Object> rawRequest;
    /** @description Zero-based index in the batch; 0 for single requests. */
    public Integer batchIndex;
}
