/**
 * Static dispatcher and entry point for processing raw JSON-RPC 2.0
 * request strings.
 *
 * Handles single requests, batch arrays, and notifications. Delegates
 * method execution to handlers registered in the supplied
 * {@link JsonRpcModule} and maps exceptions through an optional
 * {@link JsonRpcExceptionMapper} provided via
 * {@link JsonRpcServiceRuntimeOptions}.
 */
public class JsonRpcServiceRuntime {

    // ── Inner exception classes ───────────────────────────────────────

    /** Thrown when the inbound JSON cannot be parsed. */
    public class ParseFailureException extends Exception {}

    /** Thrown when a parsed request object is structurally invalid. */
    public class InvalidRequestException extends Exception {}

    /** Thrown when the requested method has no registered handler. */
    public class MethodNotFoundException extends Exception {}

    /** Thrown when the request parameters fail validation. */
    public class InvalidParamsException extends Exception {}

    // ── Public API ────────────────────────────────────────────────────

    /**
     * Parses and executes a raw JSON-RPC 2.0 request string.
     *
     * @param json    The raw JSON string (single object or batch array).
     * @param module  The handler registry to dispatch against.
     * @param options Optional runtime configuration (may be null).
     * @return An {@link JsonRpcExecutionResult} containing the response(s).
     */
    public static JsonRpcExecutionResult execute(
        String json,
        JsonRpcModule module,
        JsonRpcServiceRuntimeOptions options
    ) {
        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(json);
        } catch (Exception e) {
            JsonRpcResponse resp = JsonRpcResponse.failure(
                JsonRpcIdValue.fromNull(),
                JsonRpcError.parseError(e.getMessage())
            );
            return JsonRpcExecutionResult.singleResponse(resp);
        }

        // ── Batch request ─────────────────────────────────────────
        if (parsed instanceof List<Object>) {
            List<Object> batch = (List<Object>) parsed;
            List<JsonRpcResponse> responses = new List<JsonRpcResponse>();

            for (Integer i = 0; i < batch.size(); i++) {
                Object item = batch[i];
                if (!(item instanceof Map<String, Object>)) {
                    responses.add(
                        JsonRpcResponse.failure(
                            JsonRpcIdValue.fromNull(),
                            JsonRpcError.invalidRequest('Batch element is not a JSON object')
                        )
                    );
                    continue;
                }

                Map<String, Object> rawRequest = (Map<String, Object>) item;
                Boolean isNotification = !rawRequest.containsKey('id');

                JsonRpcResponse resp = processSingleRequest(rawRequest, i, module, options);

                if (!isNotification) {
                    responses.add(resp);
                }
            }

            return JsonRpcExecutionResult.batchResponse(responses);
        }

        // ── Single request ────────────────────────────────────────
        if (parsed instanceof Map<String, Object>) {
            Map<String, Object> rawRequest = (Map<String, Object>) parsed;
            Boolean isNotification = !rawRequest.containsKey('id');

            JsonRpcResponse resp = processSingleRequest(rawRequest, 0, module, options);

            if (isNotification) {
                return JsonRpcExecutionResult.noResponse();
            }

            return JsonRpcExecutionResult.singleResponse(resp);
        }

        // ── Neither object nor array ──────────────────────────────
        JsonRpcResponse resp = JsonRpcResponse.failure(
            JsonRpcIdValue.fromNull(),
            JsonRpcError.invalidRequest('Request must be a JSON object or array')
        );
        return JsonRpcExecutionResult.singleResponse(resp);
    }

    // ── Private helpers ───────────────────────────────────────────────

    /**
     * Validates and dispatches a single parsed request map.
     *
     * @param rawRequest The deserialized request object.
     * @param batchIndex Zero-based index within a batch (0 for single).
     * @param module     The handler registry.
     * @param options    Optional runtime configuration.
     * @return A {@link JsonRpcResponse} for this request.
     */
    private static JsonRpcResponse processSingleRequest(
        Map<String, Object> rawRequest,
        Integer batchIndex,
        JsonRpcModule module,
        JsonRpcServiceRuntimeOptions options
    ) {
        // Resolve ID early so error responses can reference it.
        JsonRpcIdValue requestId = rawRequest.containsKey('id')
            ? JsonRpcIdValue.fromRaw(rawRequest.get('id'))
            : JsonRpcIdValue.fromNull();

        try {
            // Validate jsonrpc version field.
            Object versionField = rawRequest.get('jsonrpc');
            if (versionField == null || !'2.0'.equals(String.valueOf(versionField))) {
                return JsonRpcResponse.failure(
                    requestId,
                    JsonRpcError.invalidRequest('Missing or invalid "jsonrpc" field; must be "2.0"')
                );
            }

            // Validate method field.
            Object methodField = rawRequest.get('method');
            if (methodField == null || !(methodField instanceof String)) {
                return JsonRpcResponse.failure(
                    requestId,
                    JsonRpcError.invalidRequest('Missing or non-string "method" field')
                );
            }
            String methodName = (String) methodField;

            // Look up handler.
            JsonRpcMethodHandler handler = module.getHandler(methodName);
            if (handler == null) {
                return JsonRpcResponse.failure(
                    requestId,
                    JsonRpcError.methodNotFound('Method not found: ' + methodName)
                );
            }

            // Build context and invoke.
            JsonRpcInvocationContext context = new JsonRpcInvocationContext(
                methodName,
                requestId,
                rawRequest,
                batchIndex
            );

            return handler.invoke(context);

        } catch (Exception e) {
            // Attempt custom exception mapping.
            if (options != null && options.exceptionMapper != null) {
                try {
                    JsonRpcError mapped = options.exceptionMapper.mapException(e);
                    return JsonRpcResponse.failure(requestId, mapped);
                } catch (Exception mapperEx) {
                    // Mapper itself failed; fall through to generic error.
                }
            }

            return JsonRpcResponse.failure(
                requestId,
                JsonRpcError.internalError(e.getMessage())
            );
        }
    }
}
