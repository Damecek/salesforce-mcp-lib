/**
 * @description Static JSON-RPC 2.0 dispatch runtime.
 * Parses incoming JSON, routes requests to registered handlers, and produces
 * a typed execution result containing all response envelopes.
 */
public inherited sharing class JsonRpcServiceRuntime {
    /** @description Thrown when the incoming JSON cannot be parsed. */
    public class ParseFailureException extends Exception {}
    /** @description Thrown when a request envelope is structurally invalid. */
    public class InvalidRequestException extends Exception {}
    /** @description Thrown when no handler is registered for the requested method. */
    public class MethodNotFoundException extends Exception {}
    /** @description Thrown when the params payload fails deserialization or validation. */
    public class InvalidParamsException extends Exception {}

    /**
     * @description Executes a raw JSON-RPC payload against the registered module.
     * @param requestJson Raw JSON-RPC request string (single object or batch array).
     * @param module Handler registry.
     * @param options Runtime options; when null defaults are used.
     * @return Typed execution result.
     */
    public static JsonRpcExecutionResult execute(String requestJson, JsonRpcModule module, JsonRpcServiceRuntimeOptions options) {
        JsonRpcExceptionMapper mapper = options != null ? options.exceptionMapper : null;

        Object parsed;
        try {
            parsed = JSON.deserializeUntyped(requestJson);
        } catch (Exception ex) {
            JsonRpcError error = mapException(new ParseFailureException('Parse error: ' + ex.getMessage()), null, mapper);
            return new JsonRpcExecutionResult(
                new List<JsonRpcResponse>{ JsonRpcResponse.errorResponse(null, error) },
                true,
                false
            );
        }

        if (parsed instanceof List<Object>) {
            return executeBatch((List<Object>) parsed, module, mapper);
        }
        return executeSingle(parsed, module, mapper);
    }

    private static JsonRpcExecutionResult executeSingle(Object raw, JsonRpcModule module, JsonRpcExceptionMapper mapper) {
        JsonRpcResponse response = dispatchRequest(raw, module, mapper, 0);
        if (response == null) {
            return new JsonRpcExecutionResult(new List<JsonRpcResponse>(), false, false);
        }
        return new JsonRpcExecutionResult(new List<JsonRpcResponse>{ response }, true, false);
    }

    private static JsonRpcExecutionResult executeBatch(List<Object> requests, JsonRpcModule module, JsonRpcExceptionMapper mapper) {
        if (requests.isEmpty()) {
            JsonRpcError error = mapException(new InvalidRequestException('Empty batch request.'), null, mapper);
            return new JsonRpcExecutionResult(
                new List<JsonRpcResponse>{ JsonRpcResponse.errorResponse(null, error) },
                true,
                true
            );
        }

        List<JsonRpcResponse> responses = new List<JsonRpcResponse>();
        for (Integer i = 0; i < requests.size(); i++) {
            JsonRpcResponse response = dispatchRequest(requests[i], module, mapper, i);
            if (response != null) {
                responses.add(response);
            }
        }

        return new JsonRpcExecutionResult(responses, !responses.isEmpty(), true);
    }

    private static JsonRpcResponse dispatchRequest(Object raw, JsonRpcModule module, JsonRpcExceptionMapper mapper, Integer batchIndex) {
        if (!(raw instanceof Map<String, Object>)) {
            JsonRpcError error = mapException(new InvalidRequestException('Request must be a JSON object.'), null, mapper);
            return JsonRpcResponse.errorResponse(null, error);
        }

        Map<String, Object> requestMap = (Map<String, Object>) raw;
        Object idValue = requestMap.get('id');
        Boolean isNotification = !requestMap.containsKey('id');

        if (requestMap.get('jsonrpc') != '2.0') {
            JsonRpcError error = mapException(new InvalidRequestException('jsonrpc must be "2.0".'), null, mapper);
            if (isNotification) {
                return null;
            }
            return JsonRpcResponse.errorResponse(idValue, error);
        }

        Object rawMethod = requestMap.get('method');
        if (!(rawMethod instanceof String) || String.isBlank((String) rawMethod)) {
            JsonRpcError error = mapException(new InvalidRequestException('method must be a non-empty string.'), null, mapper);
            if (isNotification) {
                return null;
            }
            return JsonRpcResponse.errorResponse(idValue, error);
        }

        String methodName = (String) rawMethod;
        JsonRpcMethodHandler handler = module.getHandler(methodName);
        JsonRpcInvocationContext context = buildContext(methodName, idValue, requestMap, batchIndex);

        if (handler == null) {
            if (isNotification) {
                return null;
            }
            JsonRpcError error = mapException(new MethodNotFoundException('Method not found: ' + methodName), context, mapper);
            return JsonRpcResponse.errorResponse(idValue, error);
        }

        JsonRpcParamsBase params;
        try {
            params = deserializeParams(requestMap.get('params'), handler.paramsType);
        } catch (Exception ex) {
            if (isNotification) {
                return null;
            }
            JsonRpcError error = mapException(ex, context, mapper);
            return JsonRpcResponse.errorResponse(idValue, error);
        }

        try {
            JsonRpcResultBase result = handler.invoke(params, context);
            if (isNotification) {
                return null;
            }
            return JsonRpcResponse.successResponse(idValue, result);
        } catch (Exception ex) {
            if (isNotification) {
                return null;
            }
            JsonRpcError error = mapException(ex, context, mapper);
            return JsonRpcResponse.errorResponse(idValue, error);
        }
    }

    private static JsonRpcParamsBase deserializeParams(Object rawParams, Type paramsType) {
        Type effectiveType = paramsType == null ? JsonRpcParamsBase.class : paramsType;
        Boolean isBaseType = String.valueOf(effectiveType) == String.valueOf(JsonRpcParamsBase.class);

        if (isBaseType) {
            return new JsonRpcParamsBase();
        }

        Object probe;
        try {
            probe = effectiveType.newInstance();
        } catch (Exception ex) {
            throw new InvalidParamsException('Params type must be instantiable.');
        }

        if (!(probe instanceof JsonRpcParamsBase)) {
            throw new InvalidParamsException('Params type must extend JsonRpcParamsBase.');
        }

        if (rawParams == null) {
            JsonRpcParamsBase instance = (JsonRpcParamsBase) probe;
            try {
                instance.validate();
            } catch (Exception ex) {
                throw new InvalidParamsException(ex.getMessage());
            }
            return instance;
        }

        if (!(rawParams instanceof Map<String, Object>)) {
            throw new InvalidParamsException('params must be a JSON object.');
        }

        JsonRpcParamsBase typed;
        try {
            typed = (JsonRpcParamsBase) JSON.deserialize(JSON.serialize(rawParams), effectiveType);
        } catch (Exception ex) {
            throw new InvalidParamsException('params do not match expected schema: ' + ex.getMessage());
        }

        try {
            typed.validate();
        } catch (Exception ex) {
            throw new InvalidParamsException(ex.getMessage());
        }

        return typed;
    }

    private static JsonRpcInvocationContext buildContext(String methodName, Object idValue, Map<String, Object> requestMap, Integer batchIndex) {
        JsonRpcInvocationContext ctx = new JsonRpcInvocationContext();
        ctx.methodName = methodName;
        ctx.requestId = idValue == null ? null : new JsonRpcIdValue(idValue);
        ctx.rawRequest = requestMap;
        ctx.batchIndex = batchIndex;
        return ctx;
    }

    private static JsonRpcError mapException(Exception ex, JsonRpcInvocationContext context, JsonRpcExceptionMapper mapper) {
        if (mapper != null) {
            return mapper.mapException(ex, context);
        }
        if (ex instanceof ParseFailureException) {
            return JsonRpcError.parseError(null);
        }
        if (ex instanceof InvalidRequestException) {
            return JsonRpcError.invalidRequest(null);
        }
        if (ex instanceof MethodNotFoundException) {
            return JsonRpcError.methodNotFound(null);
        }
        if (ex instanceof InvalidParamsException) {
            return JsonRpcError.invalidParams(null);
        }
        return JsonRpcError.internalError(null);
    }
}
