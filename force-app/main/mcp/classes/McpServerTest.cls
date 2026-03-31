/**
 * Comprehensive integration tests for {@link McpServer}.
 *
 * <p>Each test exercises the full server pipeline: build an {@code McpServer},
 * register test capabilities, construct a {@code RestRequest} with a JSON-RPC
 * body, invoke {@link McpServer#handleRequest}, and assert against the
 * deserialized {@code RestResponse} body.</p>
 */
@IsTest
public class McpServerTest {

    // ── Test doubles ──────────────────────────────────────────────────

    private class TestTool extends McpToolDefinition {
        public TestTool() {
            this.name = 'test_tool';
            this.description = 'A test tool';
        }
        public override Map<String, Object> inputSchema() {
            return new Map<String, Object>{
                'type' => 'object',
                'properties' => new Map<String, Object>{
                    'input' => new Map<String, Object>{ 'type' => 'string' }
                }
            };
        }
        public override void validate(Map<String, Object> arguments) {
            if (!arguments.containsKey('input')) {
                throw new McpInvalidParamsException('input is required');
            }
        }
        public override McpToolResult execute(Map<String, Object> arguments) {
            McpToolResult result = new McpToolResult();
            result.content = new List<McpTextContent>{ new McpTextContent('Result: ' + arguments.get('input')) };
            return result;
        }
    }

    private class ThrowingTool extends McpToolDefinition {
        public ThrowingTool() {
            this.name = 'throwing_tool';
            this.description = 'A tool that throws';
        }
        public override Map<String, Object> inputSchema() {
            return new Map<String, Object>{ 'type' => 'object' };
        }
        public override void validate(Map<String, Object> arguments) { }
        public override McpToolResult execute(Map<String, Object> arguments) {
            throw new IllegalArgumentException('Something went wrong');
        }
    }

    private class AnnotatedTool extends McpToolDefinition {
        public AnnotatedTool() {
            this.name = 'annotated_tool';
            this.description = 'A tool with annotations';
            this.annotations = new McpToolAnnotations();
            this.annotations.readOnlyHint = true;
            this.annotations.destructiveHint = false;
        }
        public override Map<String, Object> inputSchema() {
            return new Map<String, Object>{ 'type' => 'object' };
        }
        public override void validate(Map<String, Object> arguments) { }
        public override McpToolResult execute(Map<String, Object> arguments) {
            McpToolResult result = new McpToolResult();
            result.content = new List<McpTextContent>{ new McpTextContent('OK') };
            return result;
        }
    }

    // ── Shared helpers ────────────────────────────────────────────────

    private static Map<String, Object> executeRequest(McpServer server, String jsonBody) {
        RestRequest req = new RestRequest();
        req.requestBody = Blob.valueOf(jsonBody);
        RestResponse res = new RestResponse();
        server.handleRequest(req, res);
        if (res.responseBody == null) {
            return null;
        }
        return (Map<String, Object>) JSON.deserializeUntyped(res.responseBody.toString());
    }

    private static McpServer buildToolServer() {
        McpServer server = new McpServer();
        server.registerTool(new TestTool());
        return server;
    }

    // ── 1. Initialize response ────────────────────────────────────────

    @IsTest
    static void testInitializeResponse() {
        McpServer server = buildToolServer();
        String json = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"TestClient","version":"1.0.0"}}}';

        Map<String, Object> response = executeRequest(server, json);

        System.assertNotEquals(null, response, 'Response should not be null');
        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');

        System.assertEquals('2025-11-25', result.get('protocolVersion'),
            'Protocol version should be 2025-11-25');

        Map<String, Object> capabilities = (Map<String, Object>) result.get('capabilities');
        System.assertNotEquals(null, capabilities, 'Capabilities should not be null');
        System.assert(capabilities.containsKey('tools'),
            'Capabilities should include tools when tools are registered');

        Map<String, Object> serverInfo = (Map<String, Object>) result.get('serverInfo');
        System.assertNotEquals(null, serverInfo, 'serverInfo should not be null');
        System.assertEquals('SalesforceMcpServer', serverInfo.get('name'),
            'Server name should be SalesforceMcpServer');
        System.assertEquals('1.1.0', serverInfo.get('version'),
            'Server version should be 1.1.0');
    }

    // ── 2. Initialize with no capabilities ────────────────────────────

    @IsTest
    static void testInitializeWithNoCapabilities() {
        McpServer server = new McpServer();
        String json = '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"TestClient","version":"1.0.0"}}}';

        Map<String, Object> response = executeRequest(server, json);

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        Map<String, Object> capabilities = (Map<String, Object>) result.get('capabilities');
        System.assertNotEquals(null, capabilities, 'Capabilities should not be null');
        System.assert(capabilities.isEmpty(),
            'Capabilities should be an empty map when nothing is registered');
    }

    // ── 3. Ping response ──────────────────────────────────────────────

    @IsTest
    static void testPingResponse() {
        McpServer server = new McpServer();
        String json = '{"jsonrpc":"2.0","id":1,"method":"ping"}';

        Map<String, Object> response = executeRequest(server, json);

        System.assertNotEquals(null, response, 'Ping should return a response');
        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Ping result should not be null');
        System.assert(result.isEmpty(), 'Ping result should be an empty object');
    }

    // ── 4. Notification produces no response ──────────────────────────

    @IsTest
    static void testNotificationNoResponse() {
        McpServer server = new McpServer();
        // Notification: no "id" field
        String json = '{"jsonrpc":"2.0","method":"notifications/initialized"}';

        Map<String, Object> response = executeRequest(server, json);

        System.assertEquals(null, response,
            'Notification should produce no response body');
    }

    // ── 5. Tools list ─────────────────────────────────────────────────

    @IsTest
    static void testToolsList() {
        McpServer server = buildToolServer();
        String json = '{"jsonrpc":"2.0","id":1,"method":"tools/list"}';

        Map<String, Object> response = executeRequest(server, json);

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');

        List<Object> tools = (List<Object>) result.get('tools');
        System.assertNotEquals(null, tools, 'Tools array should not be null');
        System.assertEquals(1, tools.size(), 'Should have exactly one tool');

        Map<String, Object> tool = (Map<String, Object>) tools[0];
        System.assertEquals('test_tool', tool.get('name'),
            'Tool name should be test_tool');
        System.assertEquals('A test tool', tool.get('description'),
            'Tool description should match');

        Map<String, Object> inputSchema = (Map<String, Object>) tool.get('inputSchema');
        System.assertNotEquals(null, inputSchema, 'inputSchema should not be null');
        System.assertEquals('object', inputSchema.get('type'),
            'inputSchema type should be object');
    }

    // ── 6. Tools list with annotations ────────────────────────────────

    @IsTest
    static void testToolsListWithAnnotations() {
        McpServer server = new McpServer();
        server.registerTool(new AnnotatedTool());
        String json = '{"jsonrpc":"2.0","id":1,"method":"tools/list"}';

        Map<String, Object> response = executeRequest(server, json);

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        List<Object> tools = (List<Object>) result.get('tools');
        Map<String, Object> tool = (Map<String, Object>) tools[0];

        Map<String, Object> annotations = (Map<String, Object>) tool.get('annotations');
        System.assertNotEquals(null, annotations,
            'Annotations should be present for annotated tool');
        System.assertEquals(true, annotations.get('readOnlyHint'),
            'readOnlyHint should be true');
        System.assertEquals(false, annotations.get('destructiveHint'),
            'destructiveHint should be false');
    }

    // ── 7. Tools call success ─────────────────────────────────────────

    @IsTest
    static void testToolsCallSuccess() {
        McpServer server = buildToolServer();
        String json = '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"test_tool","arguments":{"input":"hello"}}}';

        Map<String, Object> response = executeRequest(server, json);

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');

        List<Object> content = (List<Object>) result.get('content');
        System.assertNotEquals(null, content, 'Content should not be null');
        System.assertEquals(1, content.size(), 'Should have one content block');

        Map<String, Object> textBlock = (Map<String, Object>) content[0];
        System.assertEquals('text', textBlock.get('type'),
            'Content type should be text');
        System.assertEquals('Result: hello', textBlock.get('text'),
            'Text should be "Result: hello"');

        // isError should be absent or null (success case)
        Object isError = result.get('isError');
        System.assert(isError == null || isError == false,
            'isError should not be true on success');
    }

    // ── 8. Tools call validation failure ──────────────────────────────

    @IsTest
    static void testToolsCallValidationFailure() {
        McpServer server = buildToolServer();
        // Missing required "input" argument
        String json = '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"test_tool","arguments":{}}}';

        Map<String, Object> response = executeRequest(server, json);

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.get('isError'),
            'isError should be true when validation fails');

        List<Object> content = (List<Object>) result.get('content');
        System.assertNotEquals(null, content, 'Content should not be null');
        Map<String, Object> textBlock = (Map<String, Object>) content[0];
        System.assert(((String) textBlock.get('text')).contains('input is required'),
            'Error text should mention "input is required"');
    }

    // ── 9. Tools call unknown tool ────────────────────────────────────

    @IsTest
    static void testToolsCallUnknownTool() {
        McpServer server = buildToolServer();
        String json = '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"nonexistent","arguments":{}}}';

        Map<String, Object> response = executeRequest(server, json);

        System.assertNotEquals(null, response, 'Response should not be null');
        Map<String, Object> error = (Map<String, Object>) response.get('error');
        System.assertNotEquals(null, error, 'Error should not be null');
        System.assertEquals(-32602, (Integer) error.get('code'),
            'Error code should be -32602 (Invalid params) for unknown tool');
    }

    // ── 10. Tools call exception returns isError ──────────────────────

    @IsTest
    static void testToolsCallExceptionReturnsIsError() {
        McpServer server = new McpServer();
        server.registerTool(new ThrowingTool());
        String json = '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"throwing_tool","arguments":{}}}';

        Map<String, Object> response = executeRequest(server, json);

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(true, result.get('isError'),
            'isError should be true when tool throws an exception');

        List<Object> content = (List<Object>) result.get('content');
        System.assertNotEquals(null, content, 'Content should not be null');
        Map<String, Object> textBlock = (Map<String, Object>) content[0];
        System.assert(((String) textBlock.get('text')).contains('Something went wrong'),
            'Error text should contain the exception message');
    }

    // ── 11. Duplicate tool registration ───────────────────────────────

    @IsTest
    static void testDuplicateToolRegistration() {
        McpServer server = new McpServer();
        server.registerTool(new TestTool());

        Boolean exceptionThrown = false;
        try {
            server.registerTool(new TestTool());
        } catch (McpExceptions.DuplicateRegistrationException e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown,
            'Registering two tools with the same name should throw DuplicateRegistrationException');
    }

    // ── 12. Method not found ──────────────────────────────────────────

    @IsTest
    static void testMethodNotFound() {
        McpServer server = new McpServer();
        String json = '{"jsonrpc":"2.0","id":1,"method":"unknown/method"}';

        Map<String, Object> response = executeRequest(server, json);

        System.assertNotEquals(null, response, 'Response should not be null');
        Map<String, Object> error = (Map<String, Object>) response.get('error');
        System.assertNotEquals(null, error, 'Error should not be null');
        System.assertEquals(-32601, (Integer) error.get('code'),
            'Error code should be -32601 (Method not found)');
    }

    // ── 13. Malformed JSON ────────────────────────────────────────────

    @IsTest
    static void testMalformedJson() {
        McpServer server = new McpServer();
        String json = '{this is not valid json!!!';

        Map<String, Object> response = executeRequest(server, json);

        System.assertNotEquals(null, response, 'Response should not be null');
        Map<String, Object> error = (Map<String, Object>) response.get('error');
        System.assertNotEquals(null, error, 'Error should not be null');
        System.assertEquals(-32700, (Integer) error.get('code'),
            'Error code should be -32700 (Parse error)');
    }

    // ── 14. Exception mapper maps McpInvalidParamsException ───────────

    @IsTest
    static void testExceptionMapperMcpInvalidParams() {
        McpJsonRpcExceptionMapper mapper = new McpJsonRpcExceptionMapper();
        McpInvalidParamsException ex = new McpInvalidParamsException('bad param');

        JsonRpcError error = mapper.mapException(ex);

        System.assertEquals(-32602, error.code,
            'McpInvalidParamsException should map to -32602');
        System.assertEquals('bad param', error.message,
            'Error message should preserve the exception message');
    }
}
