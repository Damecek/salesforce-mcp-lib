/**
 * Comprehensive unit tests for {@link JsonRpcServiceRuntime} covering the
 * full JSON-RPC 2.0 dispatch lifecycle: parsing, routing, batch handling,
 * notification detection, all five standard error codes, and custom
 * exception mapper integration.
 */
@IsTest
public class JsonRpcServiceRuntimeTest {

    // ── Test helper: params DTO ───────────────────────────────────────

    private class TestParams extends JsonRpcParamsBase {
        public String value;
    }

    // ── Test helper: result DTO ───────────────────────────────────────

    private class TestResult extends JsonRpcResultBase {
        public String echo;
    }

    // ── Test helper: handler that returns a success response ──────────

    private class TestHandler extends JsonRpcMethodHandler {

        public TestHandler() {
            super('test/echo', TestParams.class, TestResult.class);
        }

        public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
            Map<String, Object> rawParams = (Map<String, Object>) context.rawRequest.get('params');
            TestResult res = new TestResult();
            res.echo = (String) rawParams.get('value');
            return JsonRpcResponse.success(context.requestId, res);
        }
    }

    // ── Test helper: handler that always throws ───────────────────────

    private class ThrowingHandler extends JsonRpcMethodHandler {

        public ThrowingHandler() {
            super('test/throw', null, null);
        }

        public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
            throw new IllegalArgumentException('boom');
        }
    }

    // ── Test helper: handler that throws InvalidParamsException ───────

    private class InvalidParamsHandler extends JsonRpcMethodHandler {

        public InvalidParamsHandler() {
            super('test/badparams', null, null);
        }

        public override JsonRpcResponse invoke(JsonRpcInvocationContext context) {
            throw new JsonRpcServiceRuntime.InvalidParamsException('missing required field');
        }
    }

    // ── Test helper: custom exception mapper ─────────────────────────

    private class TestExceptionMapper implements JsonRpcExceptionMapper {

        public JsonRpcError mapException(Exception e) {
            if (e instanceof IllegalArgumentException) {
                return new JsonRpcError(-32001, 'Custom mapped: ' + e.getMessage());
            }
            return null;
        }
    }

    // ── Shared setup ─────────────────────────────────────────────────

    private static JsonRpcModule buildModule() {
        JsonRpcModule module = new JsonRpcModule();
        module.register(new TestHandler());
        module.register(new ThrowingHandler());
        module.register(new InvalidParamsHandler());
        return module;
    }

    private static JsonRpcServiceRuntimeOptions defaultOptions() {
        return new JsonRpcServiceRuntimeOptions();
    }

    // ── 1. JSON parsing: valid JSON parsed correctly ─────────────────

    @IsTest
    static void testValidJsonParsedCorrectly() {
        String json = '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"hello"},"id":1}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse, 'Should have a response for a request with id');
        System.assertEquals(false, result.isBatch, 'Single request should not be batch');
        System.assertEquals(1, result.responses.size(), 'Should have exactly one response');

        JsonRpcResponse resp = result.responses[0];
        System.assert(resp.hasResult, 'Response should be a success');
        System.assertEquals(null, resp.error, 'Success response should have no error');
    }

    // ── 2. Single request routing ────────────────────────────────────

    @IsTest
    static void testSingleRequestRoutesToCorrectHandler() {
        String json = '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"routed"},"id":"abc"}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assert(resp.hasResult, 'Should be a success response');

        // Verify the handler produced the correct echo value
        String resultJson = JSON.serialize(resp.result, true);
        System.assert(resultJson.contains('"echo"'), 'Result should contain echo field');
        System.assert(resultJson.contains('routed'), 'Result should contain the routed value');
    }

    // ── 3. Batch request handling ────────────────────────────────────

    @IsTest
    static void testBatchRequestProcessesAllRequests() {
        String json = '['
            + '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"first"},"id":1},'
            + '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"second"},"id":2}'
            + ']';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse, 'Batch should have a response');
        System.assert(result.isBatch, 'Should be flagged as batch');
        System.assertEquals(2, result.responses.size(), 'Should have two responses');

        System.assert(result.responses[0].hasResult, 'First response should be success');
        System.assert(result.responses[1].hasResult, 'Second response should be success');
    }

    // ── 4. Notification detection (no id = no response) ─────────────

    @IsTest
    static void testNotificationProducesNoResponse() {
        // A notification is a request without an "id" field
        String json = '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"notify"}}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assertEquals(false, result.hasResponse, 'Notification should produce no response');
    }

    // ── 5a. Parse error (-32700): malformed JSON ─────────────────────

    @IsTest
    static void testParseErrorForMalformedJson() {
        String json = '{this is not valid json!!!';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse, 'Parse error should produce a response');
        System.assertEquals(1, result.responses.size());

        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult, 'Should be an error response');
        System.assertEquals(-32700, resp.error.code, 'Error code should be -32700 (Parse error)');
    }

    // ── 5b. Invalid request (-32600): missing jsonrpc field ──────────

    @IsTest
    static void testInvalidRequestMissingJsonrpcField() {
        // Valid JSON but missing required "jsonrpc" field
        String json = '{"method":"test/echo","id":1}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult, 'Should be an error response');
        System.assertEquals(-32600, resp.error.code, 'Error code should be -32600 (Invalid Request)');
    }

    @IsTest
    static void testInvalidRequestMissingMethodField() {
        // Valid JSON but missing required "method" field
        String json = '{"jsonrpc":"2.0","id":1}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult, 'Should be an error response');
        System.assertEquals(-32600, resp.error.code, 'Error code should be -32600 (Invalid Request)');
    }

    // ── 5c. Method not found (-32601): unknown method ────────────────

    @IsTest
    static void testMethodNotFound() {
        String json = '{"jsonrpc":"2.0","method":"nonexistent/method","id":1}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult, 'Should be an error response');
        System.assertEquals(-32601, resp.error.code, 'Error code should be -32601 (Method not found)');
    }

    // ── 5d. Invalid params (-32602): inner exception ─────────────────

    @IsTest
    static void testInvalidParamsViaInnerException() {
        String json = '{"jsonrpc":"2.0","method":"test/badparams","id":1}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult, 'Should be an error response');
        System.assertEquals(-32602, resp.error.code, 'Error code should be -32602 (Invalid params)');
        System.assert(
            resp.error.message.contains('missing required field'),
            'Error message should contain the exception detail'
        );
    }

    // ── 5e. Internal error (-32603): unexpected exception ────────────

    @IsTest
    static void testInternalErrorForUnexpectedException() {
        String json = '{"jsonrpc":"2.0","method":"test/throw","id":1}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult, 'Should be an error response');
        System.assertEquals(-32603, resp.error.code, 'Error code should be -32603 (Internal error)');
    }

    // ── 6. Unknown method dispatch returns -32601 ────────────────────

    @IsTest
    static void testUnknownMethodDispatchReturnsMethodNotFound() {
        String json = '{"jsonrpc":"2.0","method":"tools/unknown","id":42}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        System.assertEquals(1, result.responses.size());

        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult);
        System.assertEquals(-32601, resp.error.code, 'Unknown method should produce -32601');
        System.assert(
            resp.error.message.containsIgnoreCase('tools/unknown'),
            'Error message should reference the unknown method name'
        );
    }

    // ── 7. Malformed JSON returns -32700 ─────────────────────────────

    @IsTest
    static void testMalformedJsonReturnsParseError() {
        String json = '{"jsonrpc": "2.0", method: test/echo}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult);
        System.assertEquals(-32700, resp.error.code, 'Malformed JSON should produce -32700');
    }

    @IsTest
    static void testEmptyStringReturnsParseError() {
        String json = '';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult);
        System.assertEquals(-32700, resp.error.code, 'Empty string should produce -32700');
    }

    // ── 8. Exception mapper integration ──────────────────────────────

    @IsTest
    static void testCustomExceptionMapperConvertsException() {
        String json = '{"jsonrpc":"2.0","method":"test/throw","id":1}';
        JsonRpcModule module = buildModule();
        JsonRpcServiceRuntimeOptions options = new JsonRpcServiceRuntimeOptions();
        options.exceptionMapper = new TestExceptionMapper();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, options);

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult, 'Should be an error response');
        System.assertEquals(-32001, resp.error.code, 'Custom mapper should set code to -32001');
        System.assert(
            resp.error.message.contains('Custom mapped'),
            'Custom mapper should set a custom message prefix'
        );
        System.assert(
            resp.error.message.contains('boom'),
            'Custom mapper should preserve original exception message'
        );
    }

    @IsTest
    static void testExceptionMapperReturningNullFallsBackToInternalError() {
        // TestExceptionMapper only handles IllegalArgumentException.
        // Use a handler that throws a different exception type to trigger
        // the null-return path and fall back to generic internal error.
        JsonRpcModule module = new JsonRpcModule();
        module.register(new InvalidParamsHandler());

        JsonRpcServiceRuntimeOptions options = new JsonRpcServiceRuntimeOptions();
        options.exceptionMapper = new TestExceptionMapper();

        // InvalidParamsHandler throws InvalidParamsException, which is not
        // IllegalArgumentException, so the mapper returns null
        String json = '{"jsonrpc":"2.0","method":"test/badparams","id":1}';
        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, options);

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult);
        // InvalidParamsException is a well-known inner exception that the
        // runtime should map to -32602 before the custom mapper is consulted
        System.assertEquals(-32602, resp.error.code,
            'InvalidParamsException should still produce -32602 regardless of mapper');
    }

    // ── 9. Batch with mixed requests ─────────────────────────────────

    @IsTest
    static void testBatchWithMixedRequestsAndErrors() {
        String json = '['
            + '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"ok"},"id":1},'       // valid
            + '{"jsonrpc":"2.0","method":"nonexistent/method","id":2},'                      // method not found
            + '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"notify"}},'           // notification (no id)
            + '{"method":"test/echo","id":3}'                                                // invalid request (no jsonrpc)
            + ']';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse, 'Batch should have a response');
        System.assert(result.isBatch, 'Should be flagged as batch');
        // Notifications produce no response entry, so we expect 3 responses
        // (valid, method-not-found, invalid-request) with the notification omitted
        System.assertEquals(3, result.responses.size(),
            'Should have 3 responses (notification produces none)');

        // First response: success
        JsonRpcResponse resp0 = result.responses[0];
        System.assert(resp0.hasResult, 'First request should succeed');

        // Second response: method not found
        JsonRpcResponse resp1 = result.responses[1];
        System.assertEquals(false, resp1.hasResult);
        System.assertEquals(-32601, resp1.error.code, 'Second should be method not found');

        // Third response: invalid request
        JsonRpcResponse resp2 = result.responses[2];
        System.assertEquals(false, resp2.hasResult);
        System.assertEquals(-32600, resp2.error.code, 'Third should be invalid request');
    }

    @IsTest
    static void testBatchWithAllNotificationsProducesNoResponse() {
        String json = '['
            + '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"a"}},'
            + '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"b"}}'
            + ']';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assertEquals(false, result.hasResponse,
            'Batch of all notifications should produce no response');
    }

    // ── Additional edge cases ────────────────────────────────────────

    @IsTest
    static void testRequestWithNullIdReturnsResponse() {
        // JSON-RPC spec: id of null is valid (not a notification)
        String json = '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"null-id"},"id":null}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse, 'Request with id:null should produce a response');
        JsonRpcResponse resp = result.responses[0];
        System.assert(resp.hasResult, 'Should be a success response');
        System.assert(resp.id.isNull(), 'Response ID should be null');
    }

    @IsTest
    static void testRequestWithStringIdPreservesId() {
        String json = '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"str"},"id":"req-42"}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assert(resp.hasResult);
        System.assertEquals('req-42', (String) resp.id.serialize(), 'String ID should be preserved');
    }

    @IsTest
    static void testRequestWithIntegerIdPreservesId() {
        String json = '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"int"},"id":99}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assert(resp.hasResult);
        // JSON.deserializeUntyped may produce Integer or Long depending on value
        Object rawId = resp.id.serialize();
        System.assert(rawId instanceof Integer, 'Integer ID should be preserved as Integer');
        System.assertEquals(99, (Integer) rawId);
    }

    @IsTest
    static void testInternalErrorWhenHandlerThrowsWithNoMapper() {
        String json = '{"jsonrpc":"2.0","method":"test/throw","id":7}';
        JsonRpcModule module = buildModule();
        JsonRpcServiceRuntimeOptions options = new JsonRpcServiceRuntimeOptions();
        // Explicitly null mapper — runtime should fall back to generic internal error
        options.exceptionMapper = null;

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, options);

        System.assert(result.hasResponse);
        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult);
        System.assertEquals(-32603, resp.error.code,
            'Handler exception with no mapper should produce -32603');
    }

    @IsTest
    static void testBatchWithSingleElementIsStillBatch() {
        String json = '[{"jsonrpc":"2.0","method":"test/echo","params":{"value":"solo"},"id":1}]';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse);
        System.assert(result.isBatch, 'Array with single element should be treated as batch');
        System.assertEquals(1, result.responses.size());
        System.assert(result.responses[0].hasResult);
    }

    @IsTest
    static void testEmptyBatchArrayReturnsInvalidRequest() {
        String json = '[]';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());

        System.assert(result.hasResponse, 'Empty batch should produce an error response');
        System.assertEquals(1, result.responses.size());

        JsonRpcResponse resp = result.responses[0];
        System.assertEquals(false, resp.hasResult);
        System.assertEquals(-32600, resp.error.code,
            'Empty batch array should be an Invalid Request per JSON-RPC 2.0 spec');
    }

    @IsTest
    static void testToJsonProducesValidWireFormat() {
        String json = '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"wire"},"id":1}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());
        String wireJson = result.toJson();

        System.assert(wireJson.contains('"jsonrpc":"2.0"'), 'Wire JSON should contain jsonrpc version');
        System.assert(wireJson.contains('"result"'), 'Success wire JSON should contain result field');
        System.assert(!wireJson.contains('"error"'), 'Success wire JSON should not contain error field');
    }

    @IsTest
    static void testErrorResponseToJsonProducesValidWireFormat() {
        String json = '{"jsonrpc":"2.0","method":"nonexistent","id":1}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());
        String wireJson = result.toJson();

        System.assert(wireJson.contains('"jsonrpc":"2.0"'), 'Wire JSON should contain jsonrpc version');
        System.assert(wireJson.contains('"error"'), 'Error wire JSON should contain error field');
        System.assert(wireJson.contains('-32601'), 'Error wire JSON should contain error code');
    }

    @IsTest
    static void testBatchToJsonProducesArrayWireFormat() {
        String json = '['
            + '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"a"},"id":1},'
            + '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"b"},"id":2}'
            + ']';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());
        String wireJson = result.toJson();

        System.assert(wireJson.startsWith('['), 'Batch wire JSON should start with [');
        System.assert(wireJson.endsWith(']'), 'Batch wire JSON should end with ]');
    }

    @IsTest
    static void testNotificationToJsonProducesEmptyString() {
        String json = '{"jsonrpc":"2.0","method":"test/echo","params":{"value":"silent"}}';
        JsonRpcModule module = buildModule();

        JsonRpcExecutionResult result = JsonRpcServiceRuntime.execute(json, module, defaultOptions());
        String wireJson = result.toJson();

        System.assertEquals('', wireJson, 'Notification should produce empty wire string');
    }
}
