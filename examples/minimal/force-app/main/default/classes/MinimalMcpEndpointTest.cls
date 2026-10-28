@IsTest
private class MinimalMcpEndpointTest {
    @IsTest
    static void echoesTheMessage() {
        RestRequest req = new RestRequest();
        req.httpMethod = 'POST';
        req.headers.put('MCP-Protocol-Version', '2025-11-25');
        req.requestBody = Blob.valueOf('{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"echo","arguments":{"message":"hello"}}}');
        RestContext.request = req;
        RestContext.response = new RestResponse();
        MinimalMcpEndpoint.post();
        Assert.areEqual(200, RestContext.response.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        Map<String, Object> result = (Map<String, Object>) body.get('result');
        Assert.areEqual('hello', ((Map<String, Object>) ((List<Object>) result.get('content'))[0]).get('text'));
    }
}
