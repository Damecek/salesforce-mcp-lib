/**
 * @description Result of executing one or more JSON-RPC 2.0 requests.
 * @example
 * {@code
 * JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(requestJson, module, options);
 * if (result.hasResponse) {
 *   String json = result.toJson();
 * }
 * }
 */
public inherited sharing class JsonRpcExecutionResult {
    /** @description True when there is at least one response to return to the caller. */
    public Boolean hasResponse;
    /** @description All response envelopes produced for this execution. Empty for notifications. */
    public List<JsonRpcResponse> responses;
    /** @description True when the original request was a JSON array (batch). */
    public Boolean isBatch;

    /**
     * @description Creates an execution result.
     * @param responseList Collected response envelopes.
     * @param hasRes Whether the caller should return content.
     * @param batch Whether the original request was a batch.
     */
    public JsonRpcExecutionResult(List<JsonRpcResponse> responseList, Boolean hasRes, Boolean batch) {
        this.responses = responseList;
        this.hasResponse = hasRes;
        this.isBatch = batch;
    }

    /**
     * @description Serializes this result to a JSON string.
     * Returns null when hasResponse is false (notifications).
     * Returns a JSON object for single requests, a JSON array for batches.
     * @return JSON string or null.
     */
    public String toJson() {
        if (!this.hasResponse || this.responses == null || this.responses.isEmpty()) {
            return null;
        }

        if (this.isBatch) {
            List<String> parts = new List<String>();
            for (JsonRpcResponse r : this.responses) {
                parts.add(serializeResponse(r));
            }
            return '[' + String.join(parts, ',') + ']';
        }

        return serializeResponse(this.responses[0]);
    }

    private static String serializeResponse(JsonRpcResponse r) {
        String idJson = serializeId(r.id);
        String bodyJson;
        if (r.hasResult) {
            bodyJson = '"result":' + JSON.serialize(r.result, true);
        } else {
            bodyJson = '"error":' + JSON.serialize(r.error, true);
        }
        return '{"jsonrpc":"2.0","id":' + idJson + ',' + bodyJson + '}';
    }

    private static String serializeId(Object idValue) {
        if (idValue == null) {
            return 'null';
        }
        if (idValue instanceof String) {
            return JSON.serialize(idValue);
        }
        return String.valueOf(idValue);
    }
}
