/**
 * Maps MCP-layer exceptions to standard JSON-RPC error objects.
 *
 * <p>Registered with the JSON-RPC runtime so that domain-specific exceptions
 * are translated into the correct error codes on the wire rather than
 * falling through to the generic internal-error handler.</p>
 *
 * <ul>
 *   <li>{@link McpInvalidParamsException} &rarr; {@code -32602 Invalid params}</li>
 *   <li>Any other {@code Exception} &rarr; {@code -32603 Internal error}</li>
 * </ul>
 */
public class McpJsonRpcExceptionMapper implements JsonRpcExceptionMapper {

    /**
     * Maps the given exception to the appropriate JSON-RPC error.
     *
     * @param e The caught exception.
     * @return A {@link JsonRpcError} with the correct code and the original message.
     */
    public JsonRpcError mapException(Exception e) {
        if (e instanceof McpInvalidParamsException) {
            return JsonRpcError.invalidParams(e.getMessage());
        }
        return JsonRpcError.internalError(e.getMessage());
    }
}
