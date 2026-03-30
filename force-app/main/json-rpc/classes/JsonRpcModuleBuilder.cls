/**
 * Abstract builder for configuring a {@link JsonRpcModule}.
 *
 * Subclasses implement {@link #configure} to register handlers on the module.
 * Consumers call {@link #build} to obtain a fully configured module instance.
 */
public abstract class JsonRpcModuleBuilder {

    /**
     * Override to register {@link JsonRpcMethodHandler} instances on the module.
     *
     * @param module The module to configure with method handlers
     */
    public abstract void configure(JsonRpcModule module);

    /**
     * Creates a new {@link JsonRpcModule}, invokes {@link #configure} to
     * populate it with handlers, and returns the configured module.
     *
     * @return A fully configured JsonRpcModule ready for use by the runtime
     */
    public JsonRpcModule build() {
        JsonRpcModule module = new JsonRpcModule();
        this.configure(module);
        return module;
    }
}
