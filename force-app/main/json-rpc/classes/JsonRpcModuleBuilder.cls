/**
 * @description Abstract base for composing a JsonRpcModule from a registration source.
 * @example
 * {@code
 * public class MyBuilder extends JsonRpcModuleBuilder {
 *   public override void configure(JsonRpcModule module) {
 *     module.register(new PingHandler());
 *   }
 * }
 * JsonRpcModule module = new MyBuilder().build();
 * }
 */
public abstract class JsonRpcModuleBuilder {
    /**
     * @description Registers all handlers into the given module.
     * @param module Target module to configure.
     */
    public abstract void configure(JsonRpcModule module);

    /**
     * @description Creates a new module and configures it via configure().
     * @return Configured JsonRpcModule.
     */
    public JsonRpcModule build() {
        JsonRpcModule module = new JsonRpcModule();
        configure(module);
        return module;
    }
}
