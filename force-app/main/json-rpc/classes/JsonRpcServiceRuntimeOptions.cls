/**
 * Runtime configuration options for the JSON-RPC service execution layer.
 *
 * Holds optional hooks and strategies that customise how the service
 * runtime processes requests.
 */
public class JsonRpcServiceRuntimeOptions {

    /**
     * Optional mapper that translates application exceptions into
     * structured {@link JsonRpcError} responses. When {@code null}
     * the runtime falls back to a generic internal-error response.
     */
    public JsonRpcExceptionMapper exceptionMapper;
}
