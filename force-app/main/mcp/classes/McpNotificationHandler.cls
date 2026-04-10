/**
 * Handles MCP notification messages such as {@code notifications/initialized}.
 *
 * <p>Notifications are fire-and-forget messages with no {@code id} field.
 * The JSON-RPC runtime discards the handler's return value for notifications
 * and returns a no-response sentinel to the transport. This handler performs
 * no processing and returns a placeholder response that is never sent on
 * the wire.</p>
 */
public inherited sharing class McpNotificationHandler extends JsonRpcMethodHandler {

    /**
     * Constructs a notification handler for the given method name.
     *
     * @param method The notification method name (e.g. {@code "notifications/initialized"}).
     */
    public McpNotificationHandler(String method) {
        super(method, null, null);
    }

    /**
     * No-op handler for notifications.
     *
     * <p>Returns a placeholder success response. The runtime will discard
     * this value because notifications carry no request ID.</p>
     *
     * @param context The invocation context for this notification.
     * @return A placeholder {@link JsonRpcResponse} (discarded by the runtime).
     */
    public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
        return JsonRpcResponse.success(JsonRpcIdValue.fromNull(), new Map<String, Object>());
    }
}
