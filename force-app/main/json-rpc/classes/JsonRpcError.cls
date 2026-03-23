/**
 * @description Typed JSON-RPC 2.0 error object with standard factory methods.
 */
public inherited sharing class JsonRpcError {
    /** @description Standard parse error code. */
    public static final Integer CODE_PARSE_ERROR = -32700;
    /** @description Standard invalid request code. */
    public static final Integer CODE_INVALID_REQUEST = -32600;
    /** @description Standard method not found code. */
    public static final Integer CODE_METHOD_NOT_FOUND = -32601;
    /** @description Standard invalid params code. */
    public static final Integer CODE_INVALID_PARAMS = -32602;
    /** @description Standard internal error code. */
    public static final Integer CODE_INTERNAL_ERROR = -32603;

    /** @description Numeric error code. */
    public Integer code;
    /** @description Human-readable error message. */
    public String message;
    /** @description Optional structured error details. */
    public Object data;

    /**
     * @description Creates an error object from explicit components.
     * @param errorCode Numeric error code.
     * @param errorMessage Human-readable message.
     * @param errorData Optional structured details.
     */
    public JsonRpcError(Integer errorCode, String errorMessage, Object errorData) {
        this.code = errorCode;
        this.message = errorMessage;
        this.data = errorData;
    }

    /**
     * @description Creates a parse error (-32700).
     * @param errorData Optional structured details.
     * @return Parse error instance.
     */
    public static JsonRpcError parseError(Object errorData) {
        return new JsonRpcError(CODE_PARSE_ERROR, 'Parse error', errorData);
    }

    /**
     * @description Creates an invalid request error (-32600).
     * @param errorData Optional structured details.
     * @return Invalid request error instance.
     */
    public static JsonRpcError invalidRequest(Object errorData) {
        return new JsonRpcError(CODE_INVALID_REQUEST, 'Invalid Request', errorData);
    }

    /**
     * @description Creates a method not found error (-32601).
     * @param errorData Optional structured details.
     * @return Method not found error instance.
     */
    public static JsonRpcError methodNotFound(Object errorData) {
        return new JsonRpcError(CODE_METHOD_NOT_FOUND, 'Method not found', errorData);
    }

    /**
     * @description Creates an invalid params error (-32602).
     * @param errorData Optional structured details.
     * @return Invalid params error instance.
     */
    public static JsonRpcError invalidParams(Object errorData) {
        return new JsonRpcError(CODE_INVALID_PARAMS, 'Invalid params', errorData);
    }

    /**
     * @description Creates an internal error (-32603).
     * @param errorData Optional structured details.
     * @return Internal error instance.
     */
    public static JsonRpcError internalError(Object errorData) {
        return new JsonRpcError(CODE_INTERNAL_ERROR, 'Internal error', errorData);
    }
}
