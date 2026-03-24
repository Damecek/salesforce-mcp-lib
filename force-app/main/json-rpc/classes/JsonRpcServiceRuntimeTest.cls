@IsTest
private class JsonRpcServiceRuntimeTest {
    private static Integer notifyCallCount = 0;
    private static JsonRpcInvocationContext capturedContext;

    // --- Test fixtures ---

    private class EchoParams extends JsonRpcParamsBase {
        public String value;

        public override void validate() {
            if (String.isBlank(this.value)) {
                throw new JsonRpcServiceRuntime.InvalidParamsException('echo requires non-empty value.');
            }
        }
    }

    private class EchoResult extends JsonRpcResultBase {
        public String echoed;

        public EchoResult(String v) {
            this.echoed = v;
        }
    }

    private class EchoHandler extends JsonRpcMethodHandler {
        public EchoHandler() {
            super('echo', EchoParams.class, EchoResult.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            EchoParams typed = (EchoParams) params;
            return new EchoResult(typed.value);
        }
    }

    private class NotifyHandler extends JsonRpcMethodHandler {
        public NotifyHandler() {
            super('notify', JsonRpcParamsBase.class, JsonRpcResultBase.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            JsonRpcServiceRuntimeTest.notifyCallCount++;
            return new JsonRpcResultBase();
        }
    }

    private class ThrowingHandler extends JsonRpcMethodHandler {
        public ThrowingHandler() {
            super('throw', JsonRpcParamsBase.class, JsonRpcResultBase.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            throw new IllegalArgumentException('Deliberate handler failure.');
        }
    }

    private static JsonRpcModule buildModule() {
        return new JsonRpcModule()
            .register(new EchoHandler())
            .register(new NotifyHandler())
            .register(new ThrowingHandler());
    }

    private static JsonRpcExecutionResult exec(String requestJson) {
        return JsonRpcServiceRuntime.execute(requestJson, buildModule(), null);
    }

    private static Map<String, Object> single(String requestJson) {
        JsonRpcExecutionResult r = exec(requestJson);
        System.assert(r.hasResponse, 'Expected a response.');
        return (Map<String, Object>) JSON.deserializeUntyped(r.toJson());
    }

    // --- Parse error ---

    @IsTest
    static void testParseErrorOnMalformedJson() {
        JsonRpcExecutionResult result = exec('not json at all {');
        System.assertEquals(true, result.hasResponse);
        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(result.toJson());
        System.assertEquals(null, payload.get('id'));
        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertEquals(JsonRpcError.CODE_PARSE_ERROR, error.get('code'));
    }

    // --- Invalid request ---

    @IsTest
    static void testInvalidRequestWhenNotAnObject() {
        Map<String, Object> payload = single('"just a string"');
        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertEquals(JsonRpcError.CODE_INVALID_REQUEST, error.get('code'));
    }

    @IsTest
    static void testInvalidRequestWhenJsonrpcMissing() {
        Map<String, Object> payload = single('{"id":1,"method":"echo","params":{"value":"x"}}');
        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertEquals(JsonRpcError.CODE_INVALID_REQUEST, error.get('code'));
    }

    @IsTest
    static void testInvalidRequestWhenMethodMissing() {
        Map<String, Object> payload = single('{"jsonrpc":"2.0","id":1}');
        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertEquals(JsonRpcError.CODE_INVALID_REQUEST, error.get('code'));
    }

    // --- Method not found ---

    @IsTest
    static void testMethodNotFound() {
        Map<String, Object> payload = single('{"jsonrpc":"2.0","id":1,"method":"missing"}');
        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertEquals(JsonRpcError.CODE_METHOD_NOT_FOUND, error.get('code'));
    }

    // --- Invalid params ---

    @IsTest
    static void testInvalidParamsWhenParamsMissing() {
        Map<String, Object> payload = single('{"jsonrpc":"2.0","id":1,"method":"echo"}');
        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertEquals(JsonRpcError.CODE_INVALID_PARAMS, error.get('code'));
    }

    @IsTest
    static void testInvalidParamsWhenParamsIsNotObject() {
        Map<String, Object> payload = single('{"jsonrpc":"2.0","id":1,"method":"echo","params":"bad"}');
        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertEquals(JsonRpcError.CODE_INVALID_PARAMS, error.get('code'));
    }

    @IsTest
    static void testInvalidParamsWhenValidationFails() {
        Map<String, Object> payload = single('{"jsonrpc":"2.0","id":1,"method":"echo","params":{"value":""}}');
        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertEquals(JsonRpcError.CODE_INVALID_PARAMS, error.get('code'));
    }

    // --- Internal error ---

    @IsTest
    static void testInternalErrorOnHandlerException() {
        Map<String, Object> payload = single('{"jsonrpc":"2.0","id":1,"method":"throw"}');
        Map<String, Object> error = (Map<String, Object>) payload.get('error');
        System.assertEquals(JsonRpcError.CODE_INTERNAL_ERROR, error.get('code'));
    }

    // --- Successful single request ---

    @IsTest
    static void testSuccessfulSingleRequest() {
        Map<String, Object> payload = single('{"jsonrpc":"2.0","id":42,"method":"echo","params":{"value":"hello"}}');
        System.assertEquals(42, payload.get('id'));
        System.assertEquals(null, payload.get('error'));
        Map<String, Object> result = (Map<String, Object>) payload.get('result');
        System.assertEquals('hello', result.get('echoed'));
    }

    @IsTest
    static void testStringIdIsPreserved() {
        Map<String, Object> payload = single('{"jsonrpc":"2.0","id":"req-1","method":"echo","params":{"value":"x"}}');
        System.assertEquals('req-1', payload.get('id'));
    }

    // --- Notification ---

    @IsTest
    static void testNotificationProducesNoResponse() {
        notifyCallCount = 0;
        JsonRpcExecutionResult result = exec('{"jsonrpc":"2.0","method":"notify"}');
        System.assertEquals(false, result.hasResponse);
        System.assertEquals(null, result.toJson());
        System.assertEquals(1, notifyCallCount);
    }

    // --- Batch ---

    @IsTest
    static void testSingleRequestBatchReturnsBatchArray() {
        String batch = '[{"jsonrpc":"2.0","id":1,"method":"echo","params":{"value":"a"}}]';
        JsonRpcExecutionResult result = exec(batch);
        System.assertEquals(true, result.hasResponse);
        List<Object> payload = (List<Object>) JSON.deserializeUntyped(result.toJson());
        System.assertEquals(1, payload.size());
    }

    @IsTest
    static void testMixedBatchWithSuccessAndError() {
        String batch =
            '[' +
            '{"jsonrpc":"2.0","id":1,"method":"echo","params":{"value":"ok"}},' +
            '{"jsonrpc":"2.0","id":2,"method":"missing"}' +
            ']';
        JsonRpcExecutionResult result = exec(batch);
        List<Object> payload = (List<Object>) JSON.deserializeUntyped(result.toJson());
        System.assertEquals(2, payload.size());

        Map<String, Object> first = (Map<String, Object>) payload[0];
        System.assertEquals(null, first.get('error'));
        Map<String, Object> firstResult = (Map<String, Object>) first.get('result');
        System.assertEquals('ok', firstResult.get('echoed'));

        Map<String, Object> second = (Map<String, Object>) payload[1];
        Map<String, Object> secondError = (Map<String, Object>) second.get('error');
        System.assertEquals(JsonRpcError.CODE_METHOD_NOT_FOUND, secondError.get('code'));
    }

    @IsTest
    static void testBatchWithAllNotificationsProducesNoResponse() {
        String batch =
            '[' +
            '{"jsonrpc":"2.0","method":"notify"},' +
            '{"jsonrpc":"2.0","method":"notify"}' +
            ']';
        JsonRpcExecutionResult result = exec(batch);
        System.assertEquals(false, result.hasResponse);
        System.assertEquals(null, result.toJson());
    }

    @IsTest
    static void testEmptyBatchReturnsInvalidRequest() {
        JsonRpcExecutionResult result = exec('[]');
        System.assertEquals(true, result.hasResponse);
        List<Object> payload = (List<Object>) JSON.deserializeUntyped(result.toJson());
        System.assertEquals(1, payload.size());
        Map<String, Object> item = (Map<String, Object>) payload[0];
        Map<String, Object> error = (Map<String, Object>) item.get('error');
        System.assertEquals(JsonRpcError.CODE_INVALID_REQUEST, error.get('code'));
    }

    @IsTest
    static void testAllInvalidBatchReturnsErrorPerItem() {
        String batch =
            '[' +
            '"not_an_object",' +
            '42' +
            ']';
        JsonRpcExecutionResult result = exec(batch);
        List<Object> payload = (List<Object>) JSON.deserializeUntyped(result.toJson());
        System.assertEquals(2, payload.size());
        for (Object item : payload) {
            Map<String, Object> response = (Map<String, Object>) item;
            Map<String, Object> error = (Map<String, Object>) response.get('error');
            System.assertEquals(JsonRpcError.CODE_INVALID_REQUEST, error.get('code'));
        }
    }

    @IsTest
    static void testMixedBatchWithNotificationExcludesItFromResponse() {
        String batch =
            '[' +
            '{"jsonrpc":"2.0","id":1,"method":"echo","params":{"value":"hi"}},' +
            '{"jsonrpc":"2.0","method":"notify"}' +
            ']';
        JsonRpcExecutionResult result = exec(batch);
        List<Object> payload = (List<Object>) JSON.deserializeUntyped(result.toJson());
        System.assertEquals(1, payload.size());
        Map<String, Object> item = (Map<String, Object>) payload[0];
        System.assertEquals(1, item.get('id'));
    }

    // --- Context fields ---

    @IsTest
    static void testContextCarriesMethodNameAndId() {
        capturedContext = null;
        JsonRpcModule module = new JsonRpcModule().register(new ContextCapture());
        JsonRpcServiceRuntime.execute(
            '{"jsonrpc":"2.0","id":99,"method":"capture","params":{}}',
            module,
            null
        );
        System.assertNotEquals(null, capturedContext);
        System.assertEquals('capture', capturedContext.methodName);
        System.assertEquals(99, capturedContext.requestId.value);
        System.assertEquals(0, capturedContext.batchIndex);
    }

    private class ContextCapture extends JsonRpcMethodHandler {
        public ContextCapture() {
            super('capture', JsonRpcParamsBase.class, JsonRpcResultBase.class);
        }

        public override JsonRpcResultBase invoke(JsonRpcParamsBase params, JsonRpcInvocationContext context) {
            JsonRpcServiceRuntimeTest.capturedContext = context;
            return new JsonRpcResultBase();
        }
    }
}
