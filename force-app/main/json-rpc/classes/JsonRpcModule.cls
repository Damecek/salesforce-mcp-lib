/**
 * Handler registry that maps JSON-RPC method names to their corresponding
 * {@link JsonRpcMethodHandler} instances.
 *
 * The module is typically populated by a {@link JsonRpcModuleBuilder} subclass
 * and then passed to the runtime for request dispatch.
 */
public class JsonRpcModule {

    private Map<String, JsonRpcMethodHandler> handlers;

    /**
     * Constructs an empty module with no registered handlers.
     */
    public JsonRpcModule() {
        this.handlers = new Map<String, JsonRpcMethodHandler>();
    }

    /**
     * Registers a handler, keyed by its declared method name.
     * If a handler for the same method name already exists it is replaced.
     *
     * @param handler The method handler to register
     */
    public void register(JsonRpcMethodHandler handler) {
        this.handlers.put(handler.method, handler);
    }

    /**
     * Returns the handler registered for the given method name.
     *
     * @param method The JSON-RPC method name to look up
     * @return The matching handler, or null if no handler is registered for the method
     */
    public JsonRpcMethodHandler getHandler(String method) {
        return this.handlers.get(method);
    }
}
