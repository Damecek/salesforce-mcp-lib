/**
 * Thrown by tool {@code validate()} methods when supplied parameters
 * fail validation.
 *
 * <p>This is a separate top-level class so that callers can catch it
 * independently of other MCP exceptions and map it to the appropriate
 * JSON-RPC invalid-params error code.</p>
 */
public class McpInvalidParamsException extends Exception {}
