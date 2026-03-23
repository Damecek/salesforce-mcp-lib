/**
 * @description Base class for typed JSON-RPC 2.0 result DTOs.
 * Extend this class to declare strongly typed result payloads for a method handler.
 */
public virtual class JsonRpcResultBase {
    /**
     * @description Validates result values before they are serialized into the response.
     * Override to enforce required fields or structural invariants.
     */
    public virtual void validate() {
    }
}
