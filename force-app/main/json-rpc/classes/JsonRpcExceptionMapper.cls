/**
 * @description Contract for mapping exceptions to JSON-RPC 2.0 error payloads.
 */
public interface JsonRpcExceptionMapper {
    /**
     * @description Maps an exception to a JSON-RPC error.
     * @param ex Exception to map.
     * @param context Invocation context at the time of failure; may be null.
     * @return JSON-RPC error payload.
     */
    JsonRpcError mapException(Exception ex, JsonRpcInvocationContext context);
}
