/**
 * Abstract base class that JSON-RPC method implementations extend.
 *
 * Each handler is constructed with the method name it handles and the
 * Apex types used for parameter deserialization and result serialization.
 * Subclasses implement {@link #invoke} to process the request.
 */
public abstract class JsonRpcMethodHandler {

    /**
     * The JSON-RPC method name this handler is registered for
     * (e.g. "initialize", "tools/list").
     */
    public String method;

    /**
     * The Apex type used to deserialize the request params.
     * May be null for methods that accept no parameters.
     */
    public System.Type paramsType;

    /**
     * The Apex type for the result object.
     * May be null for methods that produce no result.
     */
    public System.Type resultType;

    /**
     * Constructs a handler for the given JSON-RPC method.
     *
     * @param method     The JSON-RPC method name this handler handles
     * @param paramsType The Apex type for deserialized params (null if no params)
     * @param resultType The Apex type for the result (null if no result)
     */
    public JsonRpcMethodHandler(String method, System.Type paramsType, System.Type resultType) {
        this.method = method;
        this.paramsType = paramsType;
        this.resultType = resultType;
    }

    /**
     * Process the incoming JSON-RPC request and return a response.
     *
     * @param context The invocation context containing method name, request ID,
     *                raw request data, and batch index
     * @return A JsonRpcResponse containing either a result or an error
     */
    public abstract JsonRpcResponse invoke(JsonRpcInvocationContext context);
}
