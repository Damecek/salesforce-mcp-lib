@IsTest
private class McpHttpTransportTest {
    private class EchoTool implements McpToolExecutor {
        public Object execute(Map<String, Object> arguments, McpRequestContext context) {
            return new Map<String, Object>{
                'type' => 'text',
                'text' => String.valueOf(arguments.get('value'))
            };
        }
    }

    private static McpServer buildServer() {
        McpToolDefinition toolDef = new McpToolDefinition('echo.tool', 'Echoes text value.');
        return new McpServer('Transport Test', '0.0.1').registerTool(toolDef, new EchoTool());
    }

    @IsTest
    static void testHandlePostRespondsJson() {
        RestRequest request = new RestRequest();
        request.httpMethod = 'POST';
        request.requestURI = '/services/apexrest/mcp/test';
        request.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'id' => 1,
            'method' => 'tools/call',
            'params' => new Map<String, Object>{
                'name' => 'echo.tool',
                'arguments' => new Map<String, Object>{ 'value' => 'hello' }
            }
        }));

        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;

        McpHttpTransport.handlePost(buildServer());

        System.assertEquals(200, response.statusCode);
        System.assertEquals('application/json', response.headers.get('Content-Type'));
        System.assertNotEquals(null, response.responseBody);
    }

    @IsTest
    static void testHandlePostNotificationReturns204() {
        RestRequest request = new RestRequest();
        request.httpMethod = 'POST';
        request.requestURI = '/services/apexrest/mcp/test';
        request.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'jsonrpc' => '2.0',
            'method' => 'tools/list',
            'params' => new Map<String, Object>()
        }));

        RestResponse response = new RestResponse();
        RestContext.request = request;
        RestContext.response = response;

        McpHttpTransport.handlePost(buildServer());

        System.assertEquals(204, response.statusCode);
    }
}
