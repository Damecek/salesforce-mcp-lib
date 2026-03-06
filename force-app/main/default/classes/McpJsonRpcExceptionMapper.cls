/**
 * @description Deterministic JSON-RPC exception mapper for MCP operations.
 */
public inherited sharing class McpJsonRpcExceptionMapper implements JsonRpcExceptionMapper {
    /**
     * @description Maps framework exceptions to JSON-RPC standard errors.
     * @param ex Raised exception.
     * @param context Invocation context or null.
     * @return JSON-RPC error payload.
     */
    public JsonRpcError mapException(Exception ex, JsonRpcInvocationContext context) {
        if (ex instanceof McpExceptions.NotFoundException) {
            return JsonRpcError.methodNotFound(errorData(ex, context));
        }

        if (ex instanceof McpExceptions.InvalidParamsException || ex instanceof McpInvalidParamsException) {
            return JsonRpcError.invalidParams(errorData(ex, context));
        }

        return JsonRpcError.internalError(errorData(ex, context));
    }

    private Map<String, Object> errorData(Exception ex, JsonRpcInvocationContext context) {
        Map<String, Object> data = new Map<String, Object>{
            'message' => ex == null ? null : ex.getMessage()
        };

        if (context != null) {
            data.put('methodName', context.methodName);
            data.put('batchIndex', context.batchIndex);
        }

        return data;
    }
}
