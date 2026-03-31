/**
 * Comprehensive unit tests for MCP prompt capabilities.
 *
 * <p>Covers the full lifecycle through the {@link McpServer#handleRequest} pipeline:
 * registration, duplicate rejection, prompts/list (with and without arguments),
 * prompts/get, unknown prompt error handling, and capability advertisement in
 * the initialize response.</p>
 */
@IsTest
public class McpPromptTest {

    // ── Test doubles ───────────────────────────────────────────────────

    private class TestPrompt extends McpPromptDefinition {
        public TestPrompt() {
            this.name = 'test_prompt';
            this.description = 'A test prompt';
            this.arguments = new List<McpPromptArgumentDefinition>{
                new McpPromptArgumentDefinition('topic', 'The topic to discuss', true),
                new McpPromptArgumentDefinition('style', 'The style of response', false)
            };
        }
        public override McpPromptResult get(Map<String, String> arguments) {
            McpPromptResult result = new McpPromptResult();
            result.description = 'Generated prompt for: ' + arguments.get('topic');
            result.messages = new List<McpPromptMessage>{
                new McpPromptMessage('user', new McpTextContent('Tell me about ' + arguments.get('topic')))
            };
            return result;
        }
    }

    private class SimplePrompt extends McpPromptDefinition {
        public SimplePrompt() {
            this.name = 'simple_prompt';
            this.description = 'A simple prompt with no args';
        }
        public override McpPromptResult get(Map<String, String> arguments) {
            McpPromptResult result = new McpPromptResult();
            result.messages = new List<McpPromptMessage>{
                new McpPromptMessage('user', new McpTextContent('Hello'))
            };
            return result;
        }
    }

    // ── Helper ─────────────────────────────────────────────────────────

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

    // ── 1. Prompt registration ─────────────────────────────────────────

    @IsTest
    static void testPromptRegistration() {
        McpServer server = new McpServer();
        server.registerPrompt(new TestPrompt());
        // No exception means success
        System.assert(true, 'Prompt registration should succeed without exception');
    }

    // ── 2. Duplicate prompt rejection ──────────────────────────────────

    @IsTest
    static void testDuplicatePromptRejection() {
        McpServer server = new McpServer();
        server.registerPrompt(new TestPrompt());

        Boolean caught = false;
        try {
            server.registerPrompt(new TestPrompt());
        } catch (McpExceptions.DuplicateRegistrationException e) {
            caught = true;
        }
        System.assert(caught, 'Registering a duplicate prompt name should throw DuplicateRegistrationException');
    }

    // ── 3. prompts/list with arguments ─────────────────────────────────

    @IsTest
    static void testPromptsList() {
        McpServer server = new McpServer();
        server.registerPrompt(new TestPrompt());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"prompts/list","params":{}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');

        List<Object> prompts = (List<Object>) result.get('prompts');
        System.assertNotEquals(null, prompts, 'Prompts array should be present');
        System.assertEquals(1, prompts.size(), 'Should have exactly one prompt');

        Map<String, Object> entry = (Map<String, Object>) prompts[0];
        System.assertEquals('test_prompt', entry.get('name'));
        System.assertEquals('A test prompt', entry.get('description'));

        List<Object> args = (List<Object>) entry.get('arguments');
        System.assertNotEquals(null, args, 'Arguments array should be present');
        System.assertEquals(2, args.size(), 'Should have two arguments');

        Map<String, Object> arg0 = (Map<String, Object>) args[0];
        System.assertEquals('topic', arg0.get('name'));
        System.assertEquals('The topic to discuss', arg0.get('description'));
        System.assertEquals(true, arg0.get('required'));

        Map<String, Object> arg1 = (Map<String, Object>) args[1];
        System.assertEquals('style', arg1.get('name'));
        System.assertEquals('The style of response', arg1.get('description'));
        System.assertEquals(false, arg1.get('required'));
    }

    // ── 4. prompts/list with no arguments ──────────────────────────────

    @IsTest
    static void testPromptsListNoArgs() {
        McpServer server = new McpServer();
        server.registerPrompt(new SimplePrompt());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"prompts/list","params":{}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        List<Object> prompts = (List<Object>) result.get('prompts');
        System.assertEquals(1, prompts.size(), 'Should have exactly one prompt');

        Map<String, Object> entry = (Map<String, Object>) prompts[0];
        System.assertEquals('simple_prompt', entry.get('name'));
        System.assertEquals('A simple prompt with no args', entry.get('description'));
        // SimplePrompt has no arguments defined, so the arguments key should be absent
        System.assertEquals(null, entry.get('arguments'),
            'Prompt with no arguments should not include an arguments key');
    }

    // ── 5. prompts/get ─────────────────────────────────────────────────

    @IsTest
    static void testPromptsGet() {
        McpServer server = new McpServer();
        server.registerPrompt(new TestPrompt());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"prompts/get","params":{"name":"test_prompt","arguments":{"topic":"AI"}}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');

        // Verify description
        System.assertEquals('Generated prompt for: AI', result.get('description'));

        // Verify messages
        List<Object> messages = (List<Object>) result.get('messages');
        System.assertNotEquals(null, messages, 'Messages array should be present');
        System.assertEquals(1, messages.size(), 'Should have exactly one message');

        Map<String, Object> msg = (Map<String, Object>) messages[0];
        System.assertEquals('user', msg.get('role'), 'Message role should be user');

        Map<String, Object> content = (Map<String, Object>) msg.get('content');
        System.assertNotEquals(null, content, 'Content should be present');
        System.assertEquals('text', content.get('type'), 'Content type should be text');
        System.assert(
            ((String) content.get('text')).contains('AI'),
            'Content text should contain the topic argument value "AI"'
        );
        System.assertEquals('Tell me about AI', content.get('text'));
    }

    // ── 6. prompts/get unknown prompt ──────────────────────────────────

    @IsTest
    static void testPromptsGetUnknownPrompt() {
        McpServer server = new McpServer();
        server.registerPrompt(new TestPrompt());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"prompts/get","params":{"name":"nonexistent_prompt","arguments":{}}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> error = (Map<String, Object>) response.get('error');
        System.assertNotEquals(null, error, 'Error should be present');
        System.assertEquals(-32602, (Integer) error.get('code'),
            'Unknown prompt should produce error code -32602');
    }

    // ── 7. initialize includes prompt capability ───────────────────────

    @IsTest
    static void testInitializeIncludesPromptCapability() {
        McpServer server = new McpServer();
        server.registerPrompt(new TestPrompt());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');

        Map<String, Object> capabilities = (Map<String, Object>) result.get('capabilities');
        System.assertNotEquals(null, capabilities, 'Capabilities should be present');
        System.assert(capabilities.containsKey('prompts'),
            'Capabilities should include "prompts" when a prompt is registered');
    }
}
