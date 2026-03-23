@IsTest
private class CodexHarnessTest {
    private static final String CODEX_INITIALIZE_PAYLOAD =
        '{"jsonrpc":"2.0","id":0,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"codex-mcp-client","title":"Codex","version":"0.114.0"}}}';

    private static McpServer buildServer() {
        return new McpServer('Codex Harness', '9.9.9');
    }

    @IsTest
    static void testInitializeAcceptsRealCodexPayload() {
        JsonRpcExecutionResult result = buildServer().execute(CODEX_INITIALIZE_PAYLOAD);
        System.assertEquals(true, result.hasResponse);

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(result.toJson());
        System.assertEquals(0, Integer.valueOf(String.valueOf(payload.get('id'))));
        System.assertEquals(null, payload.get('error'));

        Map<String, Object> responseResult = (Map<String, Object>) payload.get('result');
        System.assertNotEquals(null, responseResult);
        System.assertEquals('2025-11-25', responseResult.get('protocolVersion'));

        Map<String, Object> serverInfo = (Map<String, Object>) responseResult.get('serverInfo');
        System.assertEquals('Codex Harness', serverInfo.get('name'));
        System.assertEquals('9.9.9', serverInfo.get('version'));

        Map<String, Object> capabilities = (Map<String, Object>) responseResult.get('capabilities');
        System.assertEquals(false, ((Map<String, Object>) capabilities.get('tools')).get('listChanged'));
        System.assertEquals(false, ((Map<String, Object>) capabilities.get('resources')).get('listChanged'));
        System.assertEquals(false, ((Map<String, Object>) capabilities.get('prompts')).get('listChanged'));
    }

    @IsTest
    static void testInitializeParamsLoadFromRawAcceptsFullCodexParams() {
        McpInitializeParams params = new McpInitializeParams();
        params.loadFromRaw(parseParams(CODEX_INITIALIZE_PAYLOAD));

        System.assertEquals('2025-11-25', params.protocolVersion);
        System.assertNotEquals(null, params.capabilities);
        System.assertEquals(0, params.capabilities.size());
        System.assertNotEquals(null, params.clientInfo);
        System.assertEquals('codex-mcp-client', params.clientInfo.name);
        System.assertEquals('Codex', params.clientInfo.title);
        System.assertEquals('0.114.0', params.clientInfo.version);
    }

    @IsTest
    static void testInitializeParamsLoadFromRawAcceptsMinimalPayload() {
        McpInitializeParams params = new McpInitializeParams();
        params.loadFromRaw(new Map<String, Object>{ 'protocolVersion' => '2025-11-25' });

        System.assertEquals('2025-11-25', params.protocolVersion);
        System.assertEquals(null, params.capabilities);
        System.assertEquals(null, params.clientInfo);
    }

    @IsTest
    static void testInitializeParamsRejectsNonObjectParams() {
        assertInvalidParams('initialize requires params to be an object.', 'bad');
    }

    @IsTest
    static void testInitializeParamsRejectsNonObjectCapabilities() {
        assertInvalidParams(
            'initialize requires capabilities to be an object when present.',
            new Map<String, Object>{ 'capabilities' => 'bad' }
        );
    }

    @IsTest
    static void testInitializeParamsRejectsNonObjectClientInfo() {
        assertInvalidParams(
            'initialize requires clientInfo to be an object when present.',
            new Map<String, Object>{ 'clientInfo' => 'bad' }
        );
    }

    private static Map<String, Object> parseParams(String requestJson) {
        Map<String, Object> request = (Map<String, Object>) JSON.deserializeUntyped(requestJson);
        return (Map<String, Object>) request.get('params');
    }

    private static void assertInvalidParams(String expectedMessage, Object rawParams) {
        try {
            new McpInitializeParams().loadFromRaw(rawParams);
            System.assert(false, 'Expected invalid params exception.');
        } catch (McpExceptions.InvalidParamsException ex) {
            System.assertEquals(expectedMessage, ex.getMessage());
        }
    }
}
