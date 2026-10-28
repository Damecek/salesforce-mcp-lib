/**
 * Thrown by handler code when the message is safe to show to the MCP client.
 * Any other exception type is reported to the client as "Internal error".
 */
public class McpException extends Exception {
}
