/**
 * @description Abstract base for typed JSON-RPC 2.0 method handlers.
 * Extend this class to implement a single JSON-RPC method.
 * @example
 * {@code
 * public class PingHandler extends JsonRpcMethodHandler {
 *   public PingHandler() {
 *     super('ping', McpEmptyParams.class, McpTextContent.class);
 *   }
 *   public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
 *     return new PingResult();
 *   }
 * }
 * }
 */
public abstract class JsonRpcMethodHandler {
    /** @description JSON-RPC method name this handler responds to. */
    public String methodName;
    /** @description Apex type for deserializing incoming params. */
    public Type paramsType;
    /** @description Apex type for the expected result payload. */
    public Type resultType;

    /**
     * @description Configures a handler for the given method name and types.
     * @param method JSON-RPC method name.
     * @param paramsTypeRef Apex type for params deserialization.
     * @param resultTypeRef Apex type for the result.
     */
    protected JsonRpcMethodHandler(String method, Type paramsTypeRef, Type resultTypeRef) {
        this.methodName = method;
        this.paramsType = paramsTypeRef;
        this.resultType = resultTypeRef;
    }

    /**
     * @description Executes the method with deserialized params and execution context.
     * @param params Deserialized parameter DTO.
     * @param context Invocation context for this request.
     * @return Typed result payload.
     */
    public abstract JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context);
}
