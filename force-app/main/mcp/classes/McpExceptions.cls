/**
 * @description Exception types used by MCP framework and mapped to JSON-RPC errors.
 */
public inherited sharing class McpExceptions {
    /** @description Thrown when a referenced MCP capability is not registered. */
    public class NotFoundException extends Exception {}

    /** @description Thrown when incoming parameters are invalid. */
    public class InvalidParamsException extends Exception {}

    /** @description Thrown for server-side runtime failures. */
    public class InternalException extends Exception {}
}
