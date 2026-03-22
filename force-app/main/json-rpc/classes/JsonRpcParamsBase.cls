/**
 * @description Base class for typed JSON-RPC 2.0 parameter DTOs.
 * Extend this class to declare strongly typed parameters for a method handler.
 */
public virtual class JsonRpcParamsBase {
    /**
     * @description Validates parameter values after deserialization.
     * Override to enforce required fields or cross-field constraints.
     */
    public virtual void validate() {
    }
}
