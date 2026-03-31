/**
 * Comprehensive unit tests for MCP resource and resource template capabilities.
 *
 * <p>Covers the full lifecycle through the {@link McpServer#handleRequest} pipeline:
 * registration, duplicate rejection, resources/list, resources/read (text and
 * binary), resources/templates/list, resources/templates/call, unknown URI
 * error handling, and capability advertisement in the initialize response.</p>
 */
@IsTest
public class McpResourceTest {

    // ── Test doubles ───────────────────────────────────────────────────

    private class TestResource extends McpResourceDefinition {
        public TestResource() {
            this.uri = 'test://resource/one';
            this.name = 'Test Resource';
            this.description = 'A test resource';
            this.mimeType = 'application/json';
        }
        public override McpResourceResult read() {
            McpResourceResult result = new McpResourceResult();
            McpResourceContentItem item = new McpResourceContentItem();
            item.uri = this.uri;
            item.mimeType = this.mimeType;
            item.text = '{"data":"hello"}';
            result.contents = new List<McpResourceContentItem>{ item };
            return result;
        }
    }

    private class BinaryResource extends McpResourceDefinition {
        public BinaryResource() {
            this.uri = 'test://resource/binary';
            this.name = 'Binary Resource';
            this.mimeType = 'application/pdf';
        }
        public override McpResourceResult read() {
            McpResourceResult result = new McpResourceResult();
            McpResourceContentItem item = new McpResourceContentItem();
            item.uri = this.uri;
            item.mimeType = this.mimeType;
            item.blobData = 'dGVzdA==';  // base64 "test"
            result.contents = new List<McpResourceContentItem>{ item };
            return result;
        }
    }

    private class TestTemplate extends McpResourceTemplateDefinition {
        public TestTemplate() {
            this.uriTemplate = 'test://resource/{id}';
            this.name = 'Test Template';
            this.description = 'A test template';
            this.mimeType = 'text/plain';
        }
        public override McpResourceResult read(Map<String, String> templateArguments) {
            McpResourceResult result = new McpResourceResult();
            McpResourceContentItem item = new McpResourceContentItem();
            item.uri = 'test://resource/' + templateArguments.get('id');
            item.mimeType = this.mimeType;
            item.text = 'Item: ' + templateArguments.get('id');
            result.contents = new List<McpResourceContentItem>{ item };
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

    // ── 1. Resource registration ───────────────────────────────────────

    @IsTest
    static void testResourceRegistration() {
        McpServer server = new McpServer();
        server.registerResource(new TestResource());
        // No exception means success
        System.assert(true, 'Resource registration should succeed without exception');
    }

    // ── 2. Duplicate resource rejection ────────────────────────────────

    @IsTest
    static void testDuplicateResourceRejection() {
        McpServer server = new McpServer();
        server.registerResource(new TestResource());

        Boolean caught = false;
        try {
            server.registerResource(new TestResource());
        } catch (McpExceptions.DuplicateRegistrationException e) {
            caught = true;
        }
        System.assert(caught, 'Registering a duplicate resource URI should throw DuplicateRegistrationException');
    }

    // ── 3. resources/list ──────────────────────────────────────────────

    @IsTest
    static void testResourcesList() {
        McpServer server = new McpServer();
        server.registerResource(new TestResource());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"resources/list","params":{}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');

        List<Object> resources = (List<Object>) result.get('resources');
        System.assertNotEquals(null, resources, 'Resources array should be present');
        System.assertEquals(1, resources.size(), 'Should have exactly one resource');

        Map<String, Object> entry = (Map<String, Object>) resources[0];
        System.assertEquals('test://resource/one', entry.get('uri'));
        System.assertEquals('Test Resource', entry.get('name'));
        System.assertEquals('A test resource', entry.get('description'));
        System.assertEquals('application/json', entry.get('mimeType'));
    }

    // ── 4. resources/read (text) ───────────────────────────────────────

    @IsTest
    static void testResourcesRead() {
        McpServer server = new McpServer();
        server.registerResource(new TestResource());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"test://resource/one"}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        List<Object> contents = (List<Object>) result.get('contents');
        System.assertNotEquals(null, contents, 'Contents array should be present');
        System.assertEquals(1, contents.size(), 'Should have exactly one content item');

        Map<String, Object> item = (Map<String, Object>) contents[0];
        System.assertEquals('{"data":"hello"}', item.get('text'),
            'Text content should match the resource output');
        System.assertEquals('test://resource/one', item.get('uri'));
        System.assertEquals('application/json', item.get('mimeType'));
    }

    // ── 5. resources/read (binary) ─────────────────────────────────────

    @IsTest
    static void testResourcesReadBinary() {
        McpServer server = new McpServer();
        server.registerResource(new BinaryResource());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"test://resource/binary"}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        List<Object> contents = (List<Object>) result.get('contents');
        System.assertEquals(1, contents.size(), 'Should have exactly one content item');

        Map<String, Object> item = (Map<String, Object>) contents[0];
        System.assertEquals('dGVzdA==', item.get('blob'),
            'Blob content should be base64-encoded');
        System.assertEquals('test://resource/binary', item.get('uri'));
        System.assertEquals('application/pdf', item.get('mimeType'));
    }

    // ── 6. resources/read unknown URI ──────────────────────────────────

    @IsTest
    static void testResourcesReadUnknownUri() {
        McpServer server = new McpServer();
        server.registerResource(new TestResource());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"test://resource/nonexistent"}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> error = (Map<String, Object>) response.get('error');
        System.assertNotEquals(null, error, 'Error should be present');
        System.assertEquals(-32602, (Integer) error.get('code'),
            'Unknown resource URI should produce error code -32602');
    }

    // ── 7. Resource template registration ──────────────────────────────

    @IsTest
    static void testResourceTemplateRegistration() {
        McpServer server = new McpServer();
        server.registerResourceTemplate(new TestTemplate());
        // No exception means success
        System.assert(true, 'Resource template registration should succeed without exception');
    }

    // ── 8. Duplicate template rejection ────────────────────────────────

    @IsTest
    static void testDuplicateTemplateRejection() {
        McpServer server = new McpServer();
        server.registerResourceTemplate(new TestTemplate());

        Boolean caught = false;
        try {
            server.registerResourceTemplate(new TestTemplate());
        } catch (McpExceptions.DuplicateRegistrationException e) {
            caught = true;
        }
        System.assert(caught, 'Registering a duplicate template URI should throw DuplicateRegistrationException');
    }

    // ── 9. resources/templates/list ────────────────────────────────────

    @IsTest
    static void testResourcesTemplatesList() {
        McpServer server = new McpServer();
        server.registerResourceTemplate(new TestTemplate());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"resources/templates/list","params":{}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');

        List<Object> templates = (List<Object>) result.get('resourceTemplates');
        System.assertNotEquals(null, templates, 'resourceTemplates array should be present');
        System.assertEquals(1, templates.size(), 'Should have exactly one template');

        Map<String, Object> entry = (Map<String, Object>) templates[0];
        System.assertEquals('test://resource/{id}', entry.get('uriTemplate'));
        System.assertEquals('Test Template', entry.get('name'));
        System.assertEquals('A test template', entry.get('description'));
        System.assertEquals('text/plain', entry.get('mimeType'));
    }

    // ── 10. resources/templates/call ───────────────────────────────────

    @IsTest
    static void testResourcesTemplatesCall() {
        McpServer server = new McpServer();
        server.registerResourceTemplate(new TestTemplate());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"resources/templates/call","params":{"uri":"test://resource/{id}","arguments":{"id":"42"}}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        List<Object> contents = (List<Object>) result.get('contents');
        System.assertNotEquals(null, contents, 'Contents array should be present');
        System.assertEquals(1, contents.size(), 'Should have exactly one content item');

        Map<String, Object> item = (Map<String, Object>) contents[0];
        System.assertEquals('Item: 42', item.get('text'),
            'Template should interpolate the id argument');
        System.assertEquals('test://resource/42', item.get('uri'),
            'URI should reflect the resolved template');
        System.assertEquals('text/plain', item.get('mimeType'));
    }

    // ── 11. initialize includes resource capability ────────────────────

    @IsTest
    static void testInitializeIncludesResourceCapability() {
        McpServer server = new McpServer();
        server.registerResource(new TestResource());

        Map<String, Object> response = executeRequest(
            server,
            '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
        );

        System.assertNotEquals(null, response, 'Response should not be null');

        Map<String, Object> result = (Map<String, Object>) response.get('result');
        System.assertNotEquals(null, result, 'Result should not be null');

        Map<String, Object> capabilities = (Map<String, Object>) result.get('capabilities');
        System.assertNotEquals(null, capabilities, 'Capabilities should be present');
        System.assert(capabilities.containsKey('resources'),
            'Capabilities should include "resources" when a resource is registered');
    }
}
