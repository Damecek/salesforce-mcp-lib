/**
 * Container that wraps one or more {@link JsonRpcResponse} instances
 * produced by executing a JSON-RPC request (or batch).
 *
 * <p>The {@link #toJson()} method builds the final wire-format JSON string
 * by hand so that the output conforms exactly to the JSON-RPC 2.0
 * specification regardless of Apex serialization quirks.</p>
 */
public class JsonRpcExecutionResult {

    /**
     * {@code false} when the inbound message was a notification (no id)
     * and therefore no response should be sent to the client.
     */
    public Boolean hasResponse;

    /** {@code true} when the result represents a batch response array. */
    public Boolean isBatch;

    /** The individual response envelopes. */
    public List<JsonRpcResponse> responses;

    // ── Factory methods ──────────────────────────────────────────────

    /**
     * Creates a result containing a single response.
     *
     * @param resp The response envelope.
     * @return A new single-response execution result.
     */
    public static JsonRpcExecutionResult singleResponse(JsonRpcResponse resp) {
        JsonRpcExecutionResult er = new JsonRpcExecutionResult();
        er.hasResponse = true;
        er.isBatch = false;
        er.responses = new List<JsonRpcResponse>{ resp };
        return er;
    }

    /**
     * Creates a result containing a batch of responses.
     *
     * @param responses The list of response envelopes.
     * @return A new batch execution result.
     */
    public static JsonRpcExecutionResult batchResponse(List<JsonRpcResponse> responses) {
        JsonRpcExecutionResult er = new JsonRpcExecutionResult();
        er.hasResponse = true;
        er.isBatch = true;
        er.responses = responses;
        return er;
    }

    /**
     * Creates a result that carries no response (notification handling).
     *
     * @return An execution result flagged as having no response.
     */
    public static JsonRpcExecutionResult noResponse() {
        JsonRpcExecutionResult er = new JsonRpcExecutionResult();
        er.hasResponse = false;
        er.isBatch = false;
        er.responses = new List<JsonRpcResponse>();
        return er;
    }

    // ── Serialization ────────────────────────────────────────────────

    /**
     * Builds the JSON-RPC 2.0 wire-format string for this execution result.
     *
     * <p>For a single response the output is a JSON object. For a batch
     * the output is a JSON array of objects. Notifications return an
     * empty string.</p>
     *
     * @return The JSON string ready to send over the transport.
     */
    public String toJson() {
        if (!this.hasResponse) {
            return '';
        }

        if (this.isBatch) {
            List<String> parts = new List<String>();
            for (JsonRpcResponse resp : this.responses) {
                parts.add(serializeSingleResponse(resp));
            }
            return '[' + String.join(parts, ',') + ']';
        }

        return serializeSingleResponse(this.responses[0]);
    }

    // ── Private helpers ──────────────────────────────────────────────

    /**
     * Serializes a single {@link JsonRpcResponse} to a JSON-RPC 2.0
     * compliant JSON string using manual string concatenation.
     */
    private static String serializeSingleResponse(JsonRpcResponse resp) {
        String idJson = serializeId(resp.id);

        if (resp.hasResult) {
            String resultJson = JSON.serialize(resp.result, true);
            return '{"jsonrpc":"2.0","id":' + idJson + ',"result":' + resultJson + '}';
        }

        String errorJson = serializeError(resp.error);
        return '{"jsonrpc":"2.0","id":' + idJson + ',"error":' + errorJson + '}';
    }

    /**
     * Serializes a {@link JsonRpcIdValue} to its JSON token.
     */
    private static String serializeId(JsonRpcIdValue idValue) {
        if (idValue == null || idValue.isNull()) {
            return 'null';
        }
        Object raw = idValue.serialize();
        if (raw instanceof String) {
            return '"' + String.valueOf(raw).replace('"', '\\"') + '"';
        }
        return String.valueOf(raw);
    }

    /**
     * Serializes a {@link JsonRpcError} to its JSON object representation.
     * Omits the {@code data} field when it is null.
     */
    private static String serializeError(JsonRpcError err) {
        String msgEscaped = err.message.replace('"', '\\"');
        String errorStr = '{"code":' + err.code + ',"message":"' + msgEscaped + '"';
        if (err.data != null) {
            errorStr += ',"data":' + JSON.serialize(err.data, true);
        }
        errorStr += '}';
        return errorStr;
    }
}
