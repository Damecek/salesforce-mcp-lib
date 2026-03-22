/**
 * @description Registry of JSON-RPC 2.0 method handlers for a single dispatch context.
 * @example
 * {@code
 * JsonRpcModule module = new JsonRpcModule();
 * module.register(new PingHandler());
 * }
 */
public inherited sharing class JsonRpcModule {
    private Map<String, JsonRpcMethodHandler> handlers = new Map<String, JsonRpcMethodHandler>();

    /**
     * @description Registers a method handler. Duplicate method names are rejected.
     * @param handler Handler to register.
     * @return Same module for fluent chaining.
     */
    public JsonRpcModule register(JsonRpcMethodHandler handler) {
        if (handler == null) {
            throw new IllegalArgumentException('Handler cannot be null.');
        }
        if (String.isBlank(handler.methodName)) {
            throw new IllegalArgumentException('Handler method name is required.');
        }
        this.handlers.put(handler.methodName, handler);
        return this;
    }

    /**
     * @description Returns the handler registered for a method name, or null.
     * @param methodName Method name to look up.
     * @return Registered handler or null.
     */
    public JsonRpcMethodHandler getHandler(String methodName) {
        return this.handlers.get(methodName);
    }
}
