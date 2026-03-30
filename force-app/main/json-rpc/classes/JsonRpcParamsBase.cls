/**
 * Abstract base class for all JSON-RPC parameter types.
 *
 * Subclasses define typed fields that map to the {@code params} object in a
 * JSON-RPC request and may override {@link #validate()} to enforce
 * domain-specific constraints before the handler is invoked.
 */
public abstract class JsonRpcParamsBase {

    /**
     * Validates the parameter values after deserialization.
     *
     * <p>The default implementation is a no-op. Subclasses should override
     * this method to throw an appropriate exception (e.g. via
     * {@link JsonRpcError#invalidParams(String)}) when required fields are
     * missing or values are out of range.</p>
     */
    public virtual void validate() {
        // Default no-op -- subclasses override as needed.
    }
}
