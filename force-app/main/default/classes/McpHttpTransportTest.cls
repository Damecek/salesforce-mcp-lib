@IsTest
private class McpHttpTransportTest {
    private class EchoTool implements McpToolExecutor {
        public McpToolResult execute(JsonRpcParamsBase arguments, McpRequestContext context) {
            McpHttpTransportTestEchoArguments typed = (McpHttpTransportTestEchoArguments) arguments;

            McpToolResult result = new McpToolResult();
            result.content.add(new McpTextContent(typed.value));
            return result;
        }
    }

    private static McpServer buildServer() {
        McpToolDefinition toolDef = new McpToolDefinition('echo.tool', 'Echoes text value.', McpHttpTransportTestEchoArguments.class);
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

        Map<String, Object> payload = (Map<String, Object>) JSON.deserializeUntyped(response.responseBody.toString());
        Map<String, Object> result = (Map<String, Object>) payload.get('result');
        List<Object> content = (List<Object>) result.get('content');
        Map<String, Object> item = (Map<String, Object>) content[0];
        System.assertEquals('hello', item.get('text'));
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
